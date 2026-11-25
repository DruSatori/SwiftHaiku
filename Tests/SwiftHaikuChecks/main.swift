// Checks the GUI-free part of SwiftHaiku: ViewBuilder, State/Binding and rendering to layout
// commands and actions. Exits non-zero on the first failure. No window is opened.
@testable import SwiftHaiku

func check(_ condition: Bool, _ what: String, line: Int = #line) {
    guard condition else { fatalError("FAIL line \(line): \(what)") }
    print("ok - \(what)")
}

struct Sample: View {
    @State var count = 0
    @State var name = "Ann"
    var showExtra: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("Count: \(count)")
            Button("Add") { count += 1 }
            TextField("Name", text: $name).frame(width: 100)
            if showExtra { Spacer() }
            if count > 0 { Text("positive") } else { Text("zero") }
        }
        .padding()
    }
}

let sample = Sample(showExtra: false)
var renderer = Renderer()
renderer.render(sample)
check(renderer.commands == [
    .beginStack(vertical: true, spacing: 0), .insets(nil),
    .beginStack(vertical: false, spacing: 4),
    .text("Count: 0"), .button("Add", id: 0), .textField("Name", text: "Ann", id: 1),
    .size(width: 100, height: nil), .text("zero"),
    .endStack, .endStack,
], "renders stacks, modifiers, if and if/else in order")

renderer.actions[0]("")
renderer.actions[1]("Bob")
check(sample.count == 1 && sample.name == "Bob", "button and text field actions write the state")

let extra = Sample(showExtra: true)
extra.count = 1
renderer = Renderer()
renderer.render(extra)
check(renderer.commands.contains(.spacer) && renderer.commands.contains(.text("positive")),
      "re-rendering picks up the other branches")
print("PASS")
