/// One step of building a window's native content; see SHWindow in CHaikuBridge.h.
enum LayoutCommand: Equatable {
    case beginStack(vertical: Bool, spacing: Float?)
    case beginBox(String)
    case beginScroll
    /// - Parameters:
    ///   - selection: The tab to show; -1 to leave it to the user.
    ///   - id: The action's id; -1 when the selection is not bound.
    case beginTabs(selection: Int, id: Int)
    case beginTab(String)
    case endTabs
    case endStack
    case insets(Float?)
    case text(String)
    case button(String, id: Int)
    case textField(String, text: String, secure: Bool, id: Int)
    case toggle(String, isOn: Bool, id: Int)
    case picker(String, options: [String], selection: Int, radio: Bool, id: Int)
    /// - Parameter value: From 0 to `steps`.
    case slider(value: Int, steps: Int, id: Int)
    /// - Parameter value: Thousandths of the total.
    case progress(String, value: Int)
    case textEditor(text: String, id: Int)
    /// - Parameter selection: The selected item; -1 for none.
    case list(items: [String], selection: Int, id: Int)
    /// - Parameter rgb: The color as 0xRRGGBB00, in an Int32's bit pattern.
    case colorPicker(String, rgb: Int, id: Int)
    case divider
    case spacer
    case size(width: Float?, height: Float?)

    /// This command with its content (a text's text, a button's or toggle's title, a field's
    /// text, a control's value) blanked out, leaving what decides which native views it makes
    /// and how they are laid out.
    var structure: LayoutCommand {
        switch self {
        case .text: .text("")
        case .button(_, let id): .button("", id: id)
        case .textField(let label, _, let secure, let id): .textField(label, text: "", secure: secure, id: id)
        case .toggle(_, _, let id): .toggle("", isOn: false, id: id)
        case .picker(let title, let options, _, let radio, let id):
            .picker(title, options: options, selection: 0, radio: radio, id: id)
        case .slider(_, let steps, let id): .slider(value: 0, steps: steps, id: id)
        case .progress(let title, _): .progress(title, value: 0)
        case .textEditor(_, let id): .textEditor(text: "", id: id)
        case .list(let items, _, let id): .list(items: items, selection: 0, id: id)
        case .colorPicker(let title, _, let id): .colorPicker(title, rgb: 0, id: id)
        case .beginTabs(_, let id): .beginTabs(selection: 0, id: id)
        case .beginStack, .beginBox, .beginScroll, .beginTab, .endTabs, .endStack, .insets, .divider,
             .spacer, .size: self
        }
    }

    /// Whether two command lists make the same native views, so that going from one to the
    /// other only needs the views' content updated in place rather than a rebuild.
    static func sameStructure(_ old: [LayoutCommand], _ new: [LayoutCommand]) -> Bool {
        old.map(\.structure) == new.map(\.structure)
    }
}

/// Turns a view tree into layout commands, and collects the actions of its controls; a control's
/// id is the index of its action.
final class Renderer {
    var commands: [LayoutCommand] = []
    private(set) var actions: [Action] = []

    /// What a control does when it changes: gets a text field's or editor's new text, or the new
    /// value of a toggle (0 or 1), picker or tab view (index), list (index, -1 for none), slider
    /// (from 0 to its steps) or color picker (0xRRGGBB00 in an Int32's bit pattern).
    typealias Action = (_ text: String, _ value: Int) -> Void

    /// Registers a control's action. - Returns: The control's id.
    func addAction(_ action: @escaping Action) -> Int {
        actions.append(action)
        return actions.count - 1
    }

    func render(_ view: some View) {
        if let primitive = view as? PrimitiveView {
            primitive.render(into: self)
        } else {
            render(view.body)
        }
    }

    func stack(vertical: Bool, spacing: Float?, _ content: some View) {
        commands.append(.beginStack(vertical: vertical, spacing: spacing))
        render(content)
        commands.append(.endStack)
    }
}
