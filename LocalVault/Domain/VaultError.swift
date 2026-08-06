import Foundation

enum VaultError: Error, Equatable, Sendable {
  case vaultNotInitialized
  case vaultLocked
  case invalidCredentialTitle
  case credentialNotFound
  case keyUnavailable
  case invalidKeyLength
  case authenticationFailed
  case corruptedCiphertext
  case encryptionFailed
  case invalidBackup
  case unsupportedBackupVersion
  case corruptedBackup
}
