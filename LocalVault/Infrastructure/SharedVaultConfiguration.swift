import Foundation

enum SharedVaultConfiguration {
  static let appGroup = "group.com.barba.localvault"
  static let keychainAccessGroup = appGroup

  static func iOSVaultURL(fileManager: FileManager = .default) -> URL {
    let fallback = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let container = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) ?? fallback
    return container
      .appendingPathComponent("LocalVault", isDirectory: true)
      .appendingPathComponent("vault.localvault")
  }
}
