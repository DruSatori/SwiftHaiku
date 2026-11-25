/// One step of building a window's native content; see SHWindow in CHaikuBridge.h.
enum LayoutCommand: Equatable {
    case beginStack(vertical: Bool, spacing: Float?)
    case endStack
    case insets(Float?)
    case text(String)
    case button(String, id: Int)
    case textField(String, text: String, id: Int)
    case spacer
    case size(width: Float?, height: Float?)

    /// This command with its content (a text's text, a button's title, a text field's text)
    /// blanked out, leaving what decides which native views it makes and how they are laid out.
    var structure: LayoutCommand {
        switch self {
        case .text: .text("")
        case .button(_, let id): .button("", id: id)
        case .textField(let label, _, let id): .textField(label, text: "", id: id)
        case .beginStack, .endStack, .insets, .spacer, .size: self
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
    private(set) var actions: [(String) -> Void] = []

    /// Registers a control's action. - Returns: The control's id.
    func addAction(_ action: @escaping (String) -> Void) -> Int {
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
