import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationSplitView {
      List {
        Label("All Items", systemImage: "tray.full")
        Label("Favorites", systemImage: "star")
      }
      .navigationTitle("LocalVault")
    } detail: {
      ContentUnavailableView(
        "No Items",
        systemImage: "lock.shield",
        description: Text("Your local vault is empty.")
      )
    }
    .frame(minWidth: 760, minHeight: 480)
  }
}

#Preview {
  ContentView()
}
