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
