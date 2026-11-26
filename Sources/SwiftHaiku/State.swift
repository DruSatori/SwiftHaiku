/// Mutable state owned by a view. Read and write it as a plain property; pass `$name` to a
/// control that edits it.
///
/// shortcut: the storage lives in the State value itself, so only state in a WindowGroup's root
/// view survives a re-render (views made inside a body are made anew, with their initial state);
/// key storage by position in the view tree when nested views need their own state.
@propertyWrapper
public struct State<Value> {
    private final class Storage {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    private let storage: Storage

    /// - Parameter wrappedValue: The initial value.
    public init(wrappedValue: Value) { storage = Storage(wrappedValue) }

    /// The current value.
    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    /// A binding that reads and writes this state.
    public var projectedValue: Binding<Value> {
        let storage = storage
        return Binding(get: { storage.value }, set: { storage.value = $0 })
    }
}

/// Read and write access to a value owned elsewhere, such as a `State`.
@propertyWrapper
public struct Binding<Value> {
    private let get: () -> Value
    private let set: (Value) -> Void

    /// - Parameters:
    ///   - get: Returns the current value.
    ///   - set: Stores a new value.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.get = get
        self.set = set
    }

    /// The current value.
    public var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }

    /// This binding.
    public var projectedValue: Binding<Value> { self }
}
