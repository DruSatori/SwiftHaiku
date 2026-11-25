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
    private var actions: [(String) -> Void] = []

    init(title: String, root: any View) {
        self.root = root
        // Called on the window thread with the window locked, which is where rebuilds must run.
        let handler: SHEventHandler = { context, id, text in
            guard let context else { return }
            let host = Unmanaged<WindowHost>.fromOpaque(context).takeUnretainedValue()
            host.handle(id: Int(id), text: text.map { String(cString: $0) } ?? "")
        }
        guard let window = SHWindow.create(title, handler, Unmanaged.passUnretained(self).toOpaque()) else {
            fatalError("cannot create the window")
        }
        self.window = window
        rebuild()
        window.show()
    }

    private func handle(id: Int, text: String) {
        guard actions.indices.contains(id) else { return }
        actions[id](text)
        rebuild()
    }

    // shortcut: rebuilds the whole native content after every event, with no diffing, so state
    // changed outside a control's action (a timer, another thread) does not show, and view state
    // other than the text field focus and selection (restored by field id) is lost; diff the
    // command lists and update in place once windows get big or need updates from elsewhere.
    private func rebuild() {
        guard let window else { return }
        let renderer = Renderer()
        renderer.render(root)
        actions = renderer.actions
        window.beginContent()
        for command in renderer.commands {
            switch command {
            case .beginStack(let vertical, let spacing): window.beginStack(vertical, spacing ?? -1)
            case .endStack: window.endStack()
            case .insets(let insets): window.setInsets(insets ?? -1)
            case .text(let text): window.addText(text)
            case .button(let title, let id): window.addButton(title, Int32(id))
            case .textField(let label, let text, let id): window.addTextField(label, text, Int32(id))
            case .spacer: window.addSpacer()
            case .size(let width, let height): window.setLastSize(width ?? -1, height ?? -1)
            }
        }
        window.endContent()
    }
}
