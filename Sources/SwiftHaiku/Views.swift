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
        renderer.commands.append(.button(title, id: renderer.addAction { _, _ in action() }))
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
        let id = renderer.addAction { new, _ in text.wrappedValue = new }
        renderer.commands.append(.textField(placeholder, text: text.wrappedValue, secure: false, id: id))
    }
}

/// A one-line text field that hides what is typed (a BTextControl with hidden typing).
public struct SecureField: View, PrimitiveView {
    let placeholder: String
    let text: Binding<String>

    /// - Parameters:
    ///   - placeholder: Shown as the field's label, as for `TextField`.
    ///   - text: The field's text; every edit writes it and refreshes the window's content.
    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }

    func render(into renderer: Renderer) {
        let id = renderer.addAction { new, _ in text.wrappedValue = new }
        renderer.commands.append(.textField(placeholder, text: text.wrappedValue, secure: true, id: id))
    }
}

/// A check box (a BCheckBox).
public struct Toggle: View, PrimitiveView {
    let title: String
    let isOn: Binding<Bool>

    /// - Parameters:
    ///   - title: The check box's label.
    ///   - isOn: Whether it is checked; every click writes it and refreshes the window's content.
    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self.isOn = isOn
    }

    func render(into renderer: Renderer) {
        let id = renderer.addAction { _, value in isOn.wrappedValue = value != 0 }
        renderer.commands.append(.toggle(title, isOn: isOn.wrappedValue, id: id))
    }
}

/// How a `Picker` shows its options.
public enum PickerStyle {
    /// A pop-up menu (a BMenuField); the default.
    case menu
    /// A column of radio buttons (BRadioButtons).
    case radioGroup
}

/// A choice of one option from a list.
///
/// shortcut: the selection is an option index and the options are strings, not SwiftUI's
/// `Hashable` tags on arbitrary content views, and the style is a method of `Picker` rather than
/// an environment value; add tags once pickers need to choose non-index values.
public struct Picker: View, PrimitiveView {
    let title: String
    let selection: Binding<Int>
    let options: [String]
    var style = PickerStyle.menu

    /// - Parameters:
    ///   - title: Shown as the label; may be empty.
    ///   - selection: The index of the chosen option in `options`.
    ///   - options: The option titles, which must not contain newlines.
    public init(_ title: String, selection: Binding<Int>, options: [String]) {
        self.title = title
        self.selection = selection
        self.options = options
    }

    /// - Returns: This picker, shown in the given style.
    public func pickerStyle(_ style: PickerStyle) -> Picker {
        var picker = self
        picker.style = style
        return picker
    }

    func render(into renderer: Renderer) {
        let id = renderer.addAction { _, value in selection.wrappedValue = value }
        renderer.commands.append(.picker(title, options: options, selection: selection.wrappedValue,
                                         radio: style == .radioGroup, id: id))
    }
}

/// A horizontal slider (a BSlider) over a range of values.
///
/// The native slider counts in whole steps: `step` if given, else 1000 steps across the range,
/// so without a step the value has a precision of a thousandth of the range.
public struct Slider: View, PrimitiveView {
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let steps: Int

    /// - Parameters:
    ///   - value: The value; written while the thumb is dragged, refreshing the window's content.
    ///   - range: The values from the left end to the right end.
    ///   - step: The distance between values; `nil` for 1000 steps across the range.
    public init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double? = nil) {
        self.value = value
        self.range = range
        let span = range.upperBound - range.lowerBound
        steps = step.map { $0 > 0 ? max(1, Int((span / $0).rounded())) : 1 } ?? 1000
    }

    func render(into renderer: Renderer) {
        let span = range.upperBound - range.lowerBound
        let lower = range.lowerBound, steps = steps, value = value
        let id = renderer.addAction { _, native in
            value.wrappedValue = lower + span * Double(native) / Double(steps)
        }
        let native = span > 0 ? ((value.wrappedValue - lower) / span * Double(steps)).rounded() : 0
        let clamped = Int(min(max(native, 0), Double(steps)))
        renderer.commands.append(.slider(value: clamped, steps: steps, id: id))
    }
}

/// A bar showing how much of a task is done (a BStatusBar), to a thousandth of the total.
public struct ProgressView: View, PrimitiveView {
    let title: String
    let fraction: Double

    /// - Parameters:
    ///   - value: How much is done, from 0 to `total`.
    ///   - total: The value when the task is done.
    public init(value: Double, total: Double = 1) { self.init("", value: value, total: total) }

    /// - Parameters:
    ///   - title: Shown above the bar.
    ///   - value: How much is done, from 0 to `total`.
    ///   - total: The value when the task is done.
    public init(_ title: String, value: Double, total: Double = 1) {
        self.title = title
        fraction = total > 0 ? min(max(value / total, 0), 1) : 0
    }

    func render(into renderer: Renderer) {
        renderer.commands.append(.progress(title, value: Int((fraction * 1000).rounded())))
    }
}

/// A line between views: horizontal in a `VStack`, vertical in an `HStack` (a BSeparatorView).
public struct Divider: View, PrimitiveView {
    public init() {}

    func render(into renderer: Renderer) { renderer.commands.append(.divider) }
}

/// A titled frame around its content, which it lays out top to bottom (a BBox).
public struct GroupBox<Content: View>: View, PrimitiveView {
    let title: String
    let content: Content

    /// - Parameter title: Shown in the frame's top edge.
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    func render(into renderer: Renderer) {
        renderer.commands.append(.beginBox(title))
        renderer.render(content)
        renderer.commands.append(.endStack)
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
