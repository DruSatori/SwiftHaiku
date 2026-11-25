import SwiftHaiku

@main
struct GalleryApp: App {
    var body: some Scene {
        WindowGroup("Gallery") {
            GalleryView()
        }
    }
}

/// Every SwiftHaiku control, each with a text bound to its state; "Show details" adds and
/// removes a section, which rebuilds the window's content.
struct GalleryView: View {
    @State private var count = 0
    @State private var name = ""
    @State private var secret = ""
    @State private var enabled = false
    @State private var size = 1
    @State private var flavor = 0
    @State private var volume = 50.0
    @State private var details = false

    private let sizes = ["Small", "Medium", "Large"]
    private let flavors = ["Vanilla", "Chocolate", "Lemon"]

    var body: some View {
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
            if details {
                GroupBox("Details") {
                    Text("This section is added and removed by a rebuild.")
                }
            }
        }
        .padding(12)
        .frame(width: 620)
    }
}
