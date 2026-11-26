# SwiftHaiku

SwiftHaiku is a small SwiftUI-style declarative API over the native libbe GUI classes (BApplication, BWindow, BGroupView, BButton, BTextControl and friends) of RenkuOS, a Haiku fork, using Swift's C++ interop. Status: early v1 and a tech demo, arm64 only so far.

## Example

```swift
import SwiftHaiku

@main
struct CounterApp: App {
    var body: some Scene {
        WindowGroup("Counter") {
            CounterView()
        }
    }
}

struct CounterView: View {
    @State private var count = 0
    @State private var name = ""

    var body: some View {
        VStack(spacing: 8) {
            Text("Count: \(count)")
            Button("Increment") { count += 1 }
            TextField("Name:", text: $name)
                .frame(width: 240)
            Text("Hello, \(name)!")
        }
        .padding(12)
    }
}
```

## What's in v1

`App`, `WindowGroup`, `View`, `ViewBuilder` (several views, `if`, `if`/`else`), `Text`, `Button`, `TextField`, `SecureField`, `Toggle`, `Picker` (`.menu` or `.radioGroup` style), `Slider`, `ProgressView`, `Divider`, `GroupBox`, `TextEditor`, `List`, `ColorPicker` (with `Color`), `ScrollView`, `TabView` (with `.tabItem(_:)`), `VStack`, `HStack`, `Spacer`, the `.padding(_:)` and `.frame(width:height:)` modifiers, `@State` and `Binding`.

## How it works

Swift cannot import or subclass `BApplication` or `BWindow` directly, so a thin C++ bridge (the `CHaikuBridge` target: `SHApp` and `SHWindow`, both marked `SWIFT_IMMORTAL_REFERENCE`) owns the native objects and builds native views with `BGroupLayout`. All logic lives in Swift: a renderer walks the view tree and turns it into a list of layout commands (begin/end stack, group box, scroll view, tab view or tab, insets, one per control, divider, spacer, size), and after every control event (a button press, a text edit, a new value) the view tree is rendered again. If the new commands have the same structure as the last ones (the same stacks, controls, ids, labels, sizes and insets), only the changed texts, titles, field texts and control values are set on the existing native views; otherwise the window's content is rebuilt from the commands, with drawing held off until it is done so it does not flash. The text field that had keyboard focus gets its focus and selection back after a rebuild, so typing keeps working.

## Building

SwiftHaiku needs the Swift 6.4.3 toolchain for RenkuOS from the RenkuOS-Swift project, expected to be checked out next to this repo (set `RENKUOS_SWIFT` to use another location). RenkuOS-Swift is not public yet, so you cannot build this today unless you have it.

To cross-build from macOS, run `scripts/build-cross.sh`. It builds the library, the Counter and Gallery examples and the checks program for RenkuOS arm64 into `.build/haiku-arm64/app`, together with the Swift runtime libraries.

On RenkuOS itself there is no SwiftPM in the 6.4.3 toolchain yet, so build with the native `c++` and `swiftc` commands listed in the header comment of `scripts/build-cross.sh`. `Package.swift` is provided for when SwiftPM is available, but it is unverified.

## Testing

`Tests/SwiftHaikuChecks` is an executable rather than a test target, because RenkuOS has neither XCTest nor Swift Testing. It checks the GUI-free part (view building, state and bindings, rendering to layout commands) and opens no window.

`scripts/run-vm.sh` (run as `VM=<name> scripts/run-vm.sh`) cross-builds, copies the programs to a RenkuOS VM with a running desktop, runs the checks, starts Counter, drives its button and text field through `hey` scripting, checks that the button presses kept the same native views (updated in place, not rebuilt), and saves before and after screenshots to `.build/screens/`. It exits 0 on success; look at the screenshots too. `scripts/run-gallery-vm.sh` starts the Gallery example instead, without the checks: it drives every control on both tabs, reads back the texts bound to their state, checks that value changes keep the native views and that showing a section rebuilds them, scrolls the scroll view, and saves `gallery-*.png` screenshots. Each script only replaces its own files in `.build/screens/`. It reaches the VM through `ssh.sh` from the RenkuOS-on-Parallels project (also not public yet), found next to RenkuOS-Swift.

## Limitations

- Any change of structure (an `if` adding or removing a view, a new label, size or id) rebuilds the whole native window content, losing view state other than text field focus and selection. State changed outside a control's action (a timer, another thread) does not show.
- `@State` only survives in a `WindowGroup`'s root view; views made inside a `body` are made anew with their initial state.
- Control ids are assigned in render order, so an `if` that adds or removes controls before a text field can move focus.
- A `Picker` selects an option index from a list of strings, not one of SwiftUI's `Hashable` tags, and `pickerStyle` is a method of `Picker`, not an environment value.
- A `List` shows strings and selects an index, not SwiftUI's identifiable data and row views; changing its items rebuilds the window's content.
- A `TabView` without a `selection` binding shows its first tab again after a rebuild.
- `ScrollView` scrolls vertically only, and like `List` and `TextEditor` needs a `.frame(height:)` to stay smaller than its content. `ColorPicker` picks opaque RGB colors only.
- A `Slider` without a `step` moves in thousandths of its range, and a `ProgressView` shows thousandths of its total.
- A `TextField` placeholder is shown as the field's label, because `BTextControl` has no placeholder.
- Only one `WindowGroup` is supported.
- Client code must enable Swift's C++ interop.
- Metrics (spacing, padding, frame sizes) are `Float`, not `CGFloat`; `.frame` applies to the last native item the view produced, so frame a stack rather than a group of views.

## License

MIT, see [LICENSE](LICENSE).
