import SwiftHaiku

@main
struct GalleryApp: App {
    var body: some Scene {
        WindowGroup("Gallery") {
            GalleryView()
        }
    }
}

/// Every SwiftHaiku control, each with a text bound to its state, on two tabs; "Show details"
/// adds and removes a section, which rebuilds the window's content.
struct GalleryView: View {
    @State private var count = 0
    @State private var name = ""
    @State private var secret = ""
    @State private var enabled = false
    @State private var size = 1
    @State private var flavor = 0
    @State private var volume = 50.0
    @State private var details = false
    @State private var tab = 0
    @State private var notes = ""
    @State private var fruit: Int? = nil
    @State private var color = Color(red: 51, green: 102, blue: 153)

    private let sizes = ["Small", "Medium", "Large"]
    private let flavors = ["Vanilla", "Chocolate", "Lemon"]
    private let fruits = ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape"]

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $tab) {
                basics.tabItem("Basics")
                more.tabItem("More")
            }
            Text("Tab: \(tab + 1)")
        }
        .padding(12)
        .frame(width: 620)
    }

    private var basics: some View {
        VStack(spacing: 8) {
            HStack {
                GroupBox("Text") {
                    HStack {
                        Button("Increment") { count += 1 }
                        Text("Count: \(count)")
                    }
                    TextField("Name:", text: $name)
                    SecureField("Password:", text: $secret)
                    Text("Hello, \(name)!")
                    Text("Password: \(secret.count) characters")
                    if details {
                        GroupBox("Details") {
                            Text("Added and removed by a rebuild.")
                        }
                    }
                    Spacer()
                }
                GroupBox("Choices") {
                    Toggle("Enabled", isOn: $enabled)
                    Text("Enabled: \(enabled ? "yes" : "no")")
                    Picker("Size:", selection: $size, options: sizes)
                    Text("Size: \(sizes[size])")
                    Picker("Flavor:", selection: $flavor, options: flavors).pickerStyle(.radioGroup)
                    Text("Flavor: \(flavors[flavor])")
                }
            }
            HStack {
                Text("Volume:")
                Slider(value: $volume, in: 0...100, step: 1)
                Divider()
                Text("\(Int(volume))")
            }
            ProgressView("Level", value: volume, total: 100)
            Divider()
            Toggle("Show details", isOn: $details)
        }
    }

    private var more: some View {
        VStack(spacing: 8) {
            TextEditor(text: $notes).frame(height: 60)
            Text("Notes: \(notes.count) characters")
            HStack {
                VStack {
                    List(fruits, selection: $fruit).frame(width: 160, height: 120)
                    Text("Selected: \(fruit.map { fruits[$0] } ?? "none")")
                }
                ScrollView {
                    Text("Row 1"); Text("Row 2"); Text("Row 3"); Text("Row 4"); Text("Row 5")
                    Text("Row 6"); Text("Row 7"); Text("Row 8"); Text("Row 9"); Text("Row 10")
                    Text("Row 11"); Text("Row 12"); Text("Row 13"); Text("Row 14"); Text("Row 15")
                    Text("Row 16"); Text("Row 17"); Text("Row 18"); Text("Row 19"); Text("Row 20")
                }
                .frame(height: 140)
            }
            ColorPicker("Color:", selection: $color)
            Text("Color: \(color.red), \(color.green), \(color.blue)")
            Spacer()
        }
    }
}
