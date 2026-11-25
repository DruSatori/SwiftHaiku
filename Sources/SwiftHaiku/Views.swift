/// A line of read-only text (a BStringView).
public struct Text: View, PrimitiveView {
    let content: String

    /// - Parameter content: The text to show.
    public init(_ content: String) { self.content = content }

    func render(into renderer: Renderer) { renderer.commands.append(.text(content)) }
}

/// A push button (a BButton).
public struct Button: View, PrimitiveView {
    let title: String
    let action: () -> Void

    /// - Parameters:
    ///   - title: The button's label.
    ///   - action: Run when the button is pressed; the window's content is refreshed afterwards.
    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    func render(into renderer: Renderer) {
        renderer.commands.append(.button(title, id: renderer.addAction { _ in action() }))
    }
}

/// A one-line editable text field (a BTextControl).
public struct TextField: View, PrimitiveView {
    let placeholder: String
    let text: Binding<String>

    /// - Parameters:
    ///   - placeholder: Shown as the field's label, to its left, since BTextControl has no
    ///     placeholder text.
    ///   - text: The field's text; every edit writes it and refreshes the window's content.
    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }

    func render(into renderer: Renderer) {
        let id = renderer.addAction { text.wrappedValue = $0 }
        renderer.commands.append(.textField(placeholder, text: text.wrappedValue, id: id))
    }
}

/// Lays its content out top to bottom (a vertical BGroupView).
public struct VStack<Content: View>: View, PrimitiveView {
    let spacing: Float?
    let content: Content

    /// - Parameter spacing: Points between items; `nil` for the system default.
    public init(spacing: Float? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    func render(into renderer: Renderer) { renderer.stack(vertical: true, spacing: spacing, content) }
}

/// Lays its content out left to right (a horizontal BGroupView).
public struct HStack<Content: View>: View, PrimitiveView {
    let spacing: Float?
    let content: Content

    /// - Parameter spacing: Points between items; `nil` for the system default.
    public init(spacing: Float? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    func render(into renderer: Renderer) { renderer.stack(vertical: false, spacing: spacing, content) }
}

/// Takes up the free space in its stack (layout glue).
public struct Spacer: View, PrimitiveView {
    public init() {}

    func render(into renderer: Renderer) { renderer.commands.append(.spacer) }
}

/// A view with insets around it; see `View.padding(_:)`.
public struct PaddedView<Content: View>: View, PrimitiveView {
    let length: Float?
    let content: Content

    func render(into renderer: Renderer) {
        renderer.commands.append(.beginStack(vertical: true, spacing: 0))
        renderer.commands.append(.insets(length))
        renderer.render(content)
        renderer.commands.append(.endStack)
    }
}

/// A view with a fixed size; see `View.frame(width:height:)`.
public struct FramedView<Content: View>: View, PrimitiveView {
    let width: Float?
    let height: Float?
    let content: Content

    func render(into renderer: Renderer) {
        renderer.render(content)
        renderer.commands.append(.size(width: width, height: height))
    }
}

extension View {
    /// Adds space around the view.
    /// - Parameter length: Points on every side; `nil` for the system default.
    public func padding(_ length: Float? = nil) -> PaddedView<Self> {
        PaddedView(length: length, content: self)
    }

    /// Fixes the view's width, height or both; a `nil` dimension stays as the layout decides.
    /// Applies to the last native item the view produced, so frame a stack, not a group of views.
    public func frame(width: Float? = nil, height: Float? = nil) -> FramedView<Self> {
        FramedView(width: width, height: height, content: self)
    }
}
