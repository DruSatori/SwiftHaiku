/// A piece of user interface, described as a function of its state, as in SwiftUI.
public protocol View {
    /// The view this view is made of.
    associatedtype Body: View

    /// The content of this view. Built-in views have `Never` here and render themselves.
    @ViewBuilder var body: Body { get }
}

extension Never: View {
    public var body: Never { fatalError("Never has no body") }
}

extension View where Body == Never {
    /// Built-in views render themselves and have no body.
    public var body: Never { fatalError("\(Self.self) is a built-in view and has no body") }
}

/// Builds a view from the statements of a closure: several views, `if`, and `if`/`else`.
@resultBuilder
public enum ViewBuilder {
    public static func buildBlock<Content: View>(_ content: Content) -> Content { content }

    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<repeat each Content> {
        TupleView(value: (repeat each content))
    }

    public static func buildOptional<Content: View>(_ content: Content?) -> Content? { content }

    public static func buildEither<First: View, Second: View>(first: First) -> ConditionalContent<First, Second> {
        .first(first)
    }

    public static func buildEither<First: View, Second: View>(second: Second) -> ConditionalContent<First, Second> {
        .second(second)
    }
}

/// Several views in a row, made by `ViewBuilder` from a block of statements.
public struct TupleView<each Content: View>: View {
    let value: (repeat each Content)

    func render(into renderer: Renderer) {
        repeat renderer.render(each value)
    }
}

/// One of two views, made by `ViewBuilder` from `if`/`else`.
public enum ConditionalContent<First: View, Second: View>: View {
    case first(First)
    case second(Second)

    func render(into renderer: Renderer) {
        switch self {
        case .first(let view): renderer.render(view)
        case .second(let view): renderer.render(view)
        }
    }
}

extension Optional: View where Wrapped: View {
    public typealias Body = Never

    func render(into renderer: Renderer) {
        if let view = self { renderer.render(view) }
    }
}

/// A view that renders itself into layout commands instead of having a body.
protocol PrimitiveView {
    func render(into renderer: Renderer)
}

extension TupleView: PrimitiveView {}
extension ConditionalContent: PrimitiveView {}
extension Optional: PrimitiveView where Wrapped: View {}
