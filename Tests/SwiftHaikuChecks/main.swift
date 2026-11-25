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
    .text("Count: 0"), .button("Add", id: 0), .textField("Name", text: "Ann", secure: false, id: 1),
    .size(width: 100, height: nil), .text("zero"),
    .endStack, .endStack,
], "renders stacks, modifiers, if and if/else in order")

renderer.actions[0]("", 0)
renderer.actions[1]("Bob", 0)
check(sample.count == 1 && sample.name == "Bob", "button and text field actions write the state")

let extra = Sample(showExtra: true)
extra.count = 1
renderer = Renderer()
renderer.render(extra)
check(renderer.commands.contains(.spacer) && renderer.commands.contains(.text("positive")),
      "re-rendering picks up the other branches")

func commands(_ view: some View) -> [LayoutCommand] {
    let renderer = Renderer()
    renderer.render(view)
    return renderer.commands
}
let before = commands(sample)
sample.count = 5
sample.name = "Cy"
check(LayoutCommand.sameStructure(before, commands(sample)),
      "new text and field text keep the structure, so the views are updated in place")
check(!LayoutCommand.sameStructure(before, commands(extra)), "an added view changes the structure")
check(!LayoutCommand.sameStructure(commands(VStack { Text("a") }), commands(HStack { Text("a") })),
      "another stack kind changes the structure")
check(!LayoutCommand.sameStructure(commands(Text("a").frame(width: 1)), commands(Text("a").frame(width: 2))),
      "another size changes the structure")
check(!LayoutCommand.sameStructure(commands(Text("a")), commands(Button("a") {})),
      "another control kind changes the structure")
check(!LayoutCommand.sameStructure([], before), "the first render builds the content")

struct Controls: View {
    @State var on = false
    @State var choice = 1
    @State var level = 25.0
    @State var secret = ""
    var radio = false

    var body: some View {
        GroupBox("Box") {
            Toggle("On", isOn: $on)
            Picker("Pick", selection: $choice, options: ["a", "b", "c"])
                .pickerStyle(radio ? .radioGroup : .menu)
            Slider(value: $level, in: 0...50, step: 5)
            ProgressView("Done", value: level, total: 50)
            SecureField("Secret", text: $secret)
            Divider()
        }
    }
}

let controls = Controls()
renderer = Renderer()
renderer.render(controls)
check(renderer.commands == [
    .beginBox("Box"), .toggle("On", isOn: false, id: 0),
    .picker("Pick", options: ["a", "b", "c"], selection: 1, radio: false, id: 1),
    .slider(value: 5, steps: 10, id: 2), .progress("Done", value: 500),
    .textField("Secret", text: "", secure: true, id: 3), .divider, .endStack,
], "renders the controls, mapping the slider to steps and the progress to thousandths")
renderer.actions[0]("", 1)
renderer.actions[1]("", 2)
renderer.actions[2]("", 7)
renderer.actions[3]("pw", 0)
check(controls.on && controls.choice == 2 && controls.level == 35 && controls.secret == "pw",
      "toggle, picker, slider and secure field actions write the state")
let controlsBefore = renderer.commands
check(LayoutCommand.sameStructure(controlsBefore, commands(controls)),
      "new values keep the structure, so the controls are updated in place")
check(!LayoutCommand.sameStructure(controlsBefore, commands(Controls(radio: true))),
      "another picker style changes the structure")
check(commands(Slider(value: Binding(get: { 2 }, set: { _ in }), in: 0...1)) == [.slider(value: 1000, steps: 1000, id: 0)],
      "a slider without a step has 1000 steps and clamps its value")
check(commands(ProgressView(value: 1, total: 0)) == [.progress("", value: 0)],
      "a progress view with no total shows nothing done")

struct Containers: View {
    @State var tab = 1
    @State var notes = "hi"
    @State var pick: Int? = nil
    @State var color = Color(red: 200, green: 16, blue: 1)
    var items = ["x", "y"]

    var body: some View {
        TabView(selection: $tab) {
            TextEditor(text: $notes).tabItem("A")
            ScrollView {
                List(items, selection: $pick)
                ColorPicker("C", selection: $color)
            }
            .tabItem("B")
        }
    }
}

let containers = Containers()
renderer = Renderer()
renderer.render(containers)
check(renderer.commands == [
    .beginTabs(selection: 1, id: 0), .beginTab("A"), .textEditor(text: "hi", id: 1), .endStack,
    .beginTab("B"), .beginScroll, .list(items: ["x", "y"], selection: -1, id: 2),
    .colorPicker("C", rgb: Int(Int32(bitPattern: 0xC8_10_01_00)), id: 3), .endStack, .endStack, .endTabs,
], "renders tabs, editor, scroll view, list and color picker, packing the color as 0xRRGGBB00")
renderer.actions[0]("", 0)
renderer.actions[1]("new", 0)
renderer.actions[2]("", 1)
renderer.actions[3]("", Int(Int32(bitPattern: 0x80_FF_7F_00)))
check(containers.tab == 0 && containers.notes == "new" && containers.pick == 1
          && containers.color == Color(red: 128, green: 255, blue: 127),
      "tab, editor, list and color actions write the state")
renderer.actions[2]("", -1)
check(containers.pick == nil, "a list reporting -1 clears the selection")
let containersBefore = renderer.commands
check(LayoutCommand.sameStructure(containersBefore, commands(containers)),
      "a new tab, text, selection or color keeps the structure, so the views are updated in place")
check(!LayoutCommand.sameStructure(containersBefore, commands(Containers(items: ["x"]))),
      "other list items change the structure")
check(commands(TabView { Text("a").tabItem("T") }) == [
    .beginTabs(selection: -1, id: -1), .beginTab("T"), .text("a"), .endStack, .endTabs,
], "an unbound tab view leaves the selection to the user and reports nothing")
print("PASS")
