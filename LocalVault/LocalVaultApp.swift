import SwiftUI

@main
struct LocalVaultApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var lockController = VaultLockController(
    authenticator: LocalAuthenticationAuthenticator()
  )
  @StateObject private var listViewModel: CredentialListViewModel

  init() {
    let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
    let vaultURL =
      applicationSupport
      .appendingPathComponent("LocalVault", isDirectory: true)
      .appendingPathComponent("vault.localvault")
    let repository = EncryptedCredentialRepository(fileURL: vaultURL)
    _listViewModel = StateObject(wrappedValue: CredentialListViewModel(repository: repository))
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(lockController)
        .environmentObject(listViewModel)
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
