import Foundation

enum VaultError: Error, Equatable, Sendable {
  case vaultNotInitialized
  case vaultLocked
  case invalidCredentialTitle
  case credentialNotFound
  case keyUnavailable
  case authenticationFailed
  case invalidBackup
  case unsupportedBackupVersion
  case corruptedBackup
}
