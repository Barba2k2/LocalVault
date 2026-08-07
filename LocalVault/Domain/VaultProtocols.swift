import Foundation

protocol CredentialRepository: Sendable {
  func initialize() async throws
  func deleteVault() async throws
  func list() async throws -> [Credential]
  func find(id: UUID) async throws -> Credential?
  func save(_ credential: Credential) async throws
  func delete(id: UUID) async throws
}

protocol VaultCryptoService: Sendable {
  func encrypt(_ plaintext: Data, using key: Data) throws -> Data
  func decrypt(_ ciphertext: Data, using key: Data) throws -> Data
}

protocol KeychainStore: Sendable {
  func readKey() throws -> Data?
  func createKeyIfNeeded() throws -> Data
  func deleteKey() throws
}

protocol BiometricAuthenticator: Sendable {
  func authenticate(reason: String) async throws
}

protocol BackupService: Sendable {
  func makeBackup(from credentials: [Credential], password: String) throws -> Data
  func restoreCredentials(from backup: Data, password: String) throws -> [Credential]
}
