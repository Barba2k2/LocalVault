// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "SharedCore",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "SharedCore", targets: ["SharedCore"]),
  ],
  targets: [
    .target(
      name: "SharedCore",
      path: "LocalVault",
      exclude: [
        "LocalVaultApp.swift",
        "ContentView.swift",
        "LocalVault.entitlements",
        "Application/CredentialListViewModel.swift",
        "Infrastructure/ClipboardManager.swift",
        "Infrastructure/KeychainVaultKeyStore.swift",
        "Infrastructure/LocalAuthenticationAuthenticator.swift",
        "Infrastructure/VaultLockController.swift",
        "Presentation",
      ]
    ),
    .testTarget(
      name: "SharedCoreTests",
      dependencies: ["SharedCore"],
      path: "SharedCoreTests"
    ),
  ]
)
