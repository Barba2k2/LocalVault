import SwiftUI

@main
struct LocalVaultApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var lockController = VaultLockController(
    authenticator: LocalAuthenticationAuthenticator()
  )

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(lockController)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        lockController.lock()
      }
    }
    .commands {
      SidebarCommands()
    }
  }
}
