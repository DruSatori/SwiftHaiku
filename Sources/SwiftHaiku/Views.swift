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

/// A multi-line editable text (a BTextView in a vertically scrolling BScrollView); give it a
/// height with `.frame`.
public struct TextEditor: View, PrimitiveView {
    let text: Binding<String>

    /// - Parameter text: The text; every edit writes it and refreshes the window's content.
    public init(text: Binding<String>) { self.text = text }

    func render(into renderer: Renderer) {
        let id = renderer.addAction { new, _ in text.wrappedValue = new }
        renderer.commands.append(.textEditor(text: text.wrappedValue, id: id))
    }
}

/// A vertically scrolling list of lines of text, of which one can be selected (a BListView in a
/// BScrollView); give it a height with `.frame`.
///
/// shortcut: the items are strings and the selection an index, not SwiftUI's identifiable data
/// and row views; a change of items rebuilds the window's content. Add data-driven rows once
/// lists need more than text.
public struct List: View, PrimitiveView {
    let items: [String]
    let selection: Binding<Int?>

    /// - Parameters:
    ///   - items: The lines, which must not contain newlines.
    ///   - selection: The index of the selected line; `nil` for none.
    public init(_ items: [String], selection: Binding<Int?>) {
        self.items = items
        self.selection = selection
    }

    func render(into renderer: Renderer) {
        let id = renderer.addAction { _, value in selection.wrappedValue = value < 0 ? nil : value }
        renderer.commands.append(.list(items: items, selection: selection.wrappedValue ?? -1, id: id))
    }
}

/// Scrolls its content, which it lays out top to bottom, vertically (a BScrollView); give it a
/// height with `.frame`, or it grows to fit its content.
public struct ScrollView<Content: View>: View, PrimitiveView {
    let content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    func render(into renderer: Renderer) {
        renderer.commands.append(.beginScroll)
        renderer.render(content)
        renderer.commands.append(.endStack)
    }
}

/// Shows one of its children at a time, picked with tabs (a BTabView). Give every child a
/// `.tabItem(_:)`, whose title labels its tab.
public struct TabView<Content: View>: View, PrimitiveView {
    let selection: Binding<Int>?
    let content: Content

    /// - Parameter selection: The index of the shown tab; `nil` to leave it to the user, in
    ///   which case a rebuild of the window's content shows the first tab again.
    public init(selection: Binding<Int>? = nil, @ViewBuilder content: () -> Content) {
        self.selection = selection
        self.content = content()
    }

    func render(into renderer: Renderer) {
        let id = selection.map { selection in renderer.addAction { _, value in selection.wrappedValue = value } }
        renderer.commands.append(.beginTabs(selection: selection?.wrappedValue ?? -1, id: id ?? -1))
        renderer.render(content)
        renderer.commands.append(.endTabs)
    }
}

/// A view shown as one tab of a `TabView`; see `View.tabItem(_:)`.
public struct TabItem<Content: View>: View, PrimitiveView {
    let title: String
    let content: Content

    func render(into renderer: Renderer) {
        renderer.commands.append(.beginTab(title))
        renderer.render(content)
        renderer.commands.append(.endStack)
    }
}

extension View {
    /// Makes the view a tab of the enclosing `TabView`, laid out top to bottom.
    /// - Parameter title: The tab's label.
    public func tabItem(_ title: String) -> TabItem<Self> { TabItem(title: title, content: self) }
}

/// An opaque RGB color, as picked by a `ColorPicker`.
public struct Color: Equatable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The color as 0xRRGGBB00 in an Int32's bit pattern, as BColorControl holds it.
    var packed: Int {
        Int(Int32(bitPattern: UInt32(red) << 24 | UInt32(green) << 16 | UInt32(blue) << 8))
    }

    init(packed: Int) {
        let value = UInt32(bitPattern: Int32(truncatingIfNeeded: packed))
        self.init(red: UInt8(value >> 24 & 0xFF), green: UInt8(value >> 16 & 0xFF), blue: UInt8(value >> 8 & 0xFF))
    }
}

/// A color chooser (a BColorControl: a palette and red, green and blue fields).
public struct ColorPicker: View, PrimitiveView {
    let title: String
    let selection: Binding<Color>

    /// - Parameters:
    ///   - title: Shown above the control; may be empty.
    ///   - selection: The color; every change writes it and refreshes the window's content.
    public init(_ title: String, selection: Binding<Color>) {
        self.title = title
        self.selection = selection
    }

    func render(into renderer: Renderer) {
        let id = renderer.addAction { _, value in selection.wrappedValue = Color(packed: value) }
        renderer.commands.append(.colorPicker(title, rgb: selection.wrappedValue.packed, id: id))
    }
}
