import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "applewatch")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, Watch!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
