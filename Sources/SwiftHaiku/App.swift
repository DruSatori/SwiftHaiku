import CHaikuBridge

/// The entry point of an app: mark the conforming type `@main`.
public protocol App {
    /// The app's scene.
    associatedtype Body: Scene

    init()

    /// The app's windows. v1 supports exactly one `WindowGroup`.
    var body: Body { get }

    /// The MIME application signature; defaults to one derived from the type name.
    static var signature: String { get }
}

extension App {
    public static var signature: String {
        "application/x-vnd.swifthaiku-\(String(describing: Self.self).lowercased())"
    }

    /// Creates the BApplication, opens the scene's window and runs until the window closes.
    public static func main() {
        guard let application = SHApp.create(signature) else { fatalError("cannot create the application") }
        guard let scene = Self().body as? OpenableScene else { fatalError("\(Body.self) is not a WindowGroup") }
        let host = scene.open()
        application.run()
        withExtendedLifetime(host) {}
    }
}

/// Part of an app's user interface; see `WindowGroup`.
public protocol Scene {}

/// A scene that can open its window.
protocol OpenableScene {
    /// - Returns: The window's host, which must stay alive while the window is open.
    func open() -> AnyObject
}

/// A window with the given title and content.
public struct WindowGroup<Content: View>: Scene, OpenableScene {
    let title: String
    let content: () -> Content

    /// - Parameters:
    ///   - title: The window title.
    ///   - content: The window's root view; made once, so its `State` lasts as long as the window.
    public init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    func open() -> AnyObject { WindowHost(title: title, root: content()) }
}

/// Owns a native window and keeps its content in step with the root view.
final class WindowHost {
    private let root: any View
    private var window: SHWindow?
    private var actions: [Renderer.Action] = []
    private var commands: [LayoutCommand] = [] // what the native content was last made from

    init(title: String, root: any View) {
        self.root = root
        // Called on the window thread with the window locked, which is where refreshes must run.
        let handler: SHEventHandler = { context, id, text, value in
            guard let context else { return }
            let host = Unmanaged<WindowHost>.fromOpaque(context).takeUnretainedValue()
            host.handle(id: Int(id), text: text.map { String(cString: $0) } ?? "", value: Int(value))
        }
        guard let window = SHWindow.create(title, handler, Unmanaged.passUnretained(self).toOpaque()) else {
            fatalError("cannot create the window")
        }
        self.window = window
        refresh()
        window.show()
    }

    private func handle(id: Int, text: String, value: Int) {
        guard actions.indices.contains(id) else { return }
        actions[id](text, value)
        refresh()
    }

    // shortcut: re-renders after every control event only, so state changed elsewhere (a timer,
    // another thread) does not show; a change of structure (an `if` adding a view, a new label,
    // size or id) still rebuilds the whole native content, drawn once so it does not flash but
    // losing view state other than text field focus and selection; diff per subtree once
    // windows get big or structure changes often.
    private func refresh() {
        guard let window else { return }
        let renderer = Renderer()
        renderer.render(root)
        actions = renderer.actions
        defer { commands = renderer.commands }
        if LayoutCommand.sameStructure(commands, renderer.commands) {
            update(window, renderer.commands)
            return
        }
        window.beginContent()
        for command in renderer.commands {
            switch command {
            case .beginStack(let vertical, let spacing): window.beginStack(vertical, spacing ?? -1)
            case .beginBox(let title): window.beginBox(title)
            case .beginScroll: window.beginScroll()
            case .beginTabs(let selection, let id): window.beginTabs(Int32(selection), Int32(id))
            case .beginTab(let title): window.beginTab(title)
            case .endTabs: window.endTabs()
            case .endStack: window.endStack()
            case .insets(let insets): window.setInsets(insets ?? -1)
            case .text(let text): window.addText(text)
            case .button(let title, let id): window.addButton(title, Int32(id))
            case .textField(let label, let text, let secure, let id):
                window.addTextField(label, text, secure, Int32(id))
            case .toggle(let title, let isOn, let id): window.addToggle(title, isOn, Int32(id))
            case .picker(let title, let options, let selection, let radio, let id):
                window.addPicker(title, options.joined(separator: "\n"), Int32(selection), radio, Int32(id))
            case .slider(let value, let steps, let id): window.addSlider(Int32(value), Int32(steps), Int32(id))
            case .progress(let title, let value): window.addProgress(title, Int32(value))
            case .textEditor(let text, let id): window.addTextEditor(text, Int32(id))
            case .list(let items, let selection, let id):
                window.addList(items.joined(separator: "\n"), Int32(selection), Int32(id))
            case .colorPicker(let title, let rgb, let id): window.addColorPicker(title, Int32(rgb), Int32(id))
            case .divider: window.addDivider()
            case .spacer: window.addSpacer()
            case .size(let width, let height): window.setLastSize(width ?? -1, height ?? -1)
            }
        }
        window.endContent()
    }

    /// Updates the content of the native views made from a list with the same structure.
    private func update(_ window: SHWindow, _ commands: [LayoutCommand]) {
        var index: Int32 = 0 // position among the leaf views, as SHWindow::setViewText counts
        for command in commands {
            switch command {
            case .text(let text), .button(let text, _), .textField(_, let text, _, _), .textEditor(let text, _):
                window.setViewText(index, text)
            case .toggle(let title, let isOn, _):
                window.setViewText(index, title)
                window.setViewValue(index, isOn ? 1 : 0)
            case .picker(_, _, let value, _, _), .slider(let value, _, _), .progress(_, let value),
                 .list(_, let value, _), .colorPicker(_, let value, _), .beginTabs(let value, _):
                window.setViewValue(index, Int32(value))
            case .divider: break
            case .beginStack, .beginBox, .beginScroll, .beginTab, .endTabs, .endStack, .insets, .spacer, .size:
                continue // no leaf view
            }
            index += 1
        }
    }
}
