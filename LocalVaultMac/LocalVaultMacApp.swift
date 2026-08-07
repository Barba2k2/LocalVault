import AppKit
import SwiftUI

@main
struct LocalVaultMacApp: App {
  @Environment(\.openWindow) private var openWindow
  @StateObject private var lockController = VaultLockController(
    authenticator: LocalAuthenticationAuthenticator()
  )
  @StateObject private var listViewModel: CredentialListViewModel

  init() {
    let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
    let vaultURL = applicationSupport
      .appendingPathComponent("LocalVault", isDirectory: true)
      .appendingPathComponent("macos-vault.localvault")
    let repository = EncryptedCredentialRepository(
      fileURL: vaultURL,
      keyStore: KeychainVaultKeyStore(service: "com.barba.localvault.macos")
    )
    _listViewModel = StateObject(wrappedValue: CredentialListViewModel(repository: repository))
  }

  var body: some Scene {
    MenuBarExtra("LocalVault", systemImage: "lock.shield") {
      Button("Open LocalVault") {
        openWindow(id: "main")
      }
      Divider()
      Button("Quit LocalVault") {
        NSApplication.shared.terminate(nil)
      }
    }
    .menuBarExtraStyle(.menu)

    Window("LocalVault", id: "main") {
      ContentView()
        .environmentObject(lockController)
        .environmentObject(listViewModel)
    }
    .commands {
      SidebarCommands()
    }
  }
}
