import Foundation

actor EncryptedCredentialRepository: CredentialRepository {
  private static let currentSchemaVersion = 1

  private struct VaultFile: Codable {
    let schemaVersion: Int
    let ciphertext: Data
  }

  private let fileURL: URL
  private let cryptoService: any VaultCryptoService
  private let keyStore: any KeychainStore

  init(
    fileURL: URL,
    cryptoService: any VaultCryptoService = CryptoKitVaultCryptoService(),
    keyStore: any KeychainStore = KeychainVaultKeyStore()
  ) {
    self.fileURL = fileURL
    self.cryptoService = cryptoService
    self.keyStore = keyStore
  }

  func list() async throws -> [Credential] {
    try loadCredentials()
  }

  func find(id: UUID) async throws -> Credential? {
    try loadCredentials().first { $0.id == id }
  }

  func save(_ credential: Credential) async throws {
    guard !credential.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw VaultError.invalidCredentialTitle
    }

    var credentials = try loadCredentials()
    if let index = credentials.firstIndex(where: { $0.id == credential.id }) {
      credentials[index] = credential
    } else {
      credentials.append(credential)
    }

    try persist(credentials)
  }

  func delete(id: UUID) async throws {
    var credentials = try loadCredentials()
    credentials.removeAll { $0.id == id }
    try persist(credentials)
  }

  private func loadCredentials() throws -> [Credential] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return []
    }

    do {
      let fileData = try Data(contentsOf: fileURL)
      let vaultFile = try JSONDecoder().decode(VaultFile.self, from: fileData)

      guard vaultFile.schemaVersion == Self.currentSchemaVersion else {
        throw VaultError.unsupportedSchemaVersion
      }

      guard let key = try keyStore.readKey() else {
        throw VaultError.keyUnavailable
      }

      let plaintext = try cryptoService.decrypt(vaultFile.ciphertext, using: key)
      return try JSONDecoder().decode([Credential].self, from: plaintext)
    } catch let error as VaultError {
      throw error
    } catch {
      throw VaultError.invalidStoredData
    }
  }

  private func persist(_ credentials: [Credential]) throws {
    do {
      let key = try keyStore.createKeyIfNeeded()
      let plaintext = try JSONEncoder().encode(credentials)
      let ciphertext = try cryptoService.encrypt(plaintext, using: key)
      let vaultFile = VaultFile(
        schemaVersion: Self.currentSchemaVersion,
        ciphertext: ciphertext
      )
      let fileData = try JSONEncoder().encode(vaultFile)

      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try fileData.write(to: fileURL, options: .atomic)
    } catch let error as VaultError {
      throw error
    } catch {
      throw VaultError.persistenceFailure
    }
  }
}
