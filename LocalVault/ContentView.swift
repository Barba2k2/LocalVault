import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var lockController: VaultLockController

  var body: some View {
    Group {
      if lockController.isLocked {
        lockedContent
      } else {
        vaultContent
      }
    }
    .frame(minWidth: 760, minHeight: 480)
    .task {
      await lockController.unlock()
    }
  }

  private var lockedContent: some View {
    VStack(spacing: 16) {
      Image(systemName: "lock.shield")
        .font(.system(size: 42))
      Text("LocalVault is locked")
        .font(.title2)
      Button(lockController.state == .unlocking ? "Authenticating…" : "Unlock") {
        Task { await lockController.unlock() }
      }
      .disabled(lockController.state == .unlocking)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var vaultContent: some View {
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
    .privacySensitive()
  }
}

#Preview {
  ContentView()
    .environmentObject(VaultLockController(authenticator: PreviewAuthenticator()))
}

private struct PreviewAuthenticator: BiometricAuthenticator {
  func authenticate(reason: String) async throws {}
}
