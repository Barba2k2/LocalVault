import Foundation
import Testing

@testable import LocalVault

struct LocalVaultTests {
  @Test func appModuleLoads() {
    _ = ContentView()
  }

  @Test func credentialHasExpectedMVPFields() {
    let createdAt = Date(timeIntervalSince1970: 1_000)
    let credential = Credential(
      title: "Example",
      username: "user@example.com",
      password: "secret",
      url: URL(string: "https://example.com"),
      notes: "Note",
      category: "Work",
      createdAt: createdAt
    )

    #expect(credential.title == "Example")
    #expect(credential.username == "user@example.com")
    #expect(credential.password == "secret")
    #expect(credential.url?.absoluteString == "https://example.com")
    #expect(credential.createdAt == createdAt)
    #expect(credential.updatedAt == createdAt)
  }

  @Test func credentialRoundTripsCodable() throws {
    let credential = Credential(title: "Example", password: "secret")
    let data = try JSONEncoder().encode(credential)
    let decoded = try JSONDecoder().decode(Credential.self, from: data)

    #expect(decoded == credential)
  }

  @Test func cryptoServiceRoundTripsData() throws {
    let service = CryptoKitVaultCryptoService()
    let key = Data(repeating: 0x11, count: 32)
    let plaintext = Data("local secret".utf8)

    let ciphertext = try service.encrypt(plaintext, using: key)
    let decrypted = try service.decrypt(ciphertext, using: key)

    #expect(ciphertext != plaintext)
    #expect(decrypted == plaintext)
  }

  @Test func cryptoServiceRejectsTamperedCiphertext() throws {
    let service = CryptoKitVaultCryptoService()
    let key = Data(repeating: 0x22, count: 32)
    var ciphertext = try service.encrypt(Data("secret".utf8), using: key)
    ciphertext[ciphertext.index(before: ciphertext.endIndex)] ^= 0x01

    var failedAuthentication = false
    do {
      _ = try service.decrypt(ciphertext, using: key)
    } catch VaultError.authenticationFailed {
      failedAuthentication = true
    }

    #expect(failedAuthentication)
  }

  @Test func cryptoServiceRejectsWrongKey() throws {
    let service = CryptoKitVaultCryptoService()
    let key = Data(repeating: 0x33, count: 32)
    let wrongKey = Data(repeating: 0x44, count: 32)
    let ciphertext = try service.encrypt(Data("secret".utf8), using: key)

    var failedAuthentication = false
    do {
      _ = try service.decrypt(ciphertext, using: wrongKey)
    } catch VaultError.authenticationFailed {
      failedAuthentication = true
    }

    #expect(failedAuthentication)
  }

  @Test func cryptoServiceRejectsInvalidKeyLength() {
    let service = CryptoKitVaultCryptoService()
    let invalidKey = Data(repeating: 0x55, count: 16)

    var rejectedKey = false
    do {
      _ = try service.encrypt(Data("secret".utf8), using: invalidKey)
    } catch VaultError.invalidKeyLength {
      rejectedKey = true
    } catch {
      rejectedKey = false
    }

    #expect(rejectedKey)
  }

  @Test func keychainStoreCreatesReadsAndDeletesVaultKey() throws {
    let store = KeychainVaultKeyStore(
      service: "com.barba.localvault.tests.\(UUID().uuidString)",
      account: "vault-key"
    )
    defer { try? store.deleteKey() }

    let createdKey = try store.createKeyIfNeeded()
    let readKey = try store.readKey()
    let repeatedKey = try store.createKeyIfNeeded()

    #expect(createdKey.count == 32)
    #expect(readKey == createdKey)
    #expect(repeatedKey == createdKey)

    try store.deleteKey()
    #expect(try store.readKey() == nil)
  }

  @Test func encryptedRepositoryPersistsCRUDWithoutPlaintext() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("vault.localvault")
    let keyStore = KeychainVaultKeyStore(
      service: "com.barba.localvault.tests.\(UUID().uuidString)",
      account: "vault-key"
    )
    let repository = EncryptedCredentialRepository(fileURL: fileURL, keyStore: keyStore)
    let credential = Credential(
      title: "Example",
      username: "user@example.com",
      password: "never-readable",
      notes: "private"
    )
    defer {
      try? keyStore.deleteKey()
      try? FileManager.default.removeItem(at: directory)
    }

    try await repository.save(credential)
    #expect(try await repository.find(id: credential.id) == credential)

    let storedBytes = try Data(contentsOf: fileURL)
    #expect(String(data: storedBytes, encoding: .utf8)?.contains("never-readable") == false)
    #expect(String(data: storedBytes, encoding: .utf8)?.contains("Example") == false)

    var updated = credential
    updated.password = "updated-secret"
    try await repository.save(updated)
    #expect(try await repository.list() == [updated])

    try await repository.delete(id: credential.id)
    #expect(try await repository.list().isEmpty)
  }

  @Test func encryptedRepositoryRejectsUnsupportedSchemaVersion() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("vault.localvault")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let invalidFile = ["schemaVersion": 999, "ciphertext": ""] as [String: Any]
    let invalidData = try JSONSerialization.data(withJSONObject: invalidFile)
    try invalidData.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: directory) }

    let repository = EncryptedCredentialRepository(fileURL: fileURL)
    var rejectedVersion = false
    do {
      _ = try await repository.list()
    } catch VaultError.unsupportedSchemaVersion {
      rejectedVersion = true
    }

    #expect(rejectedVersion)
  }

  @MainActor
  @Test func lockControllerStartsLockedAndUnlocksAfterAuthentication() async {
    let controller = VaultLockController(authenticator: TestAuthenticator(result: .success))

    #expect(controller.state == .locked)
    await controller.unlock()
    #expect(controller.state == .unlocked)

    controller.lock()
    #expect(controller.isLocked)
  }

  @MainActor
  @Test func lockControllerFailsClosedAfterAuthenticationFailure() async {
    let controller = VaultLockController(authenticator: TestAuthenticator(result: .failure))

    await controller.unlock()

    #expect(controller.state == .locked)
    #expect(controller.isLocked)
  }
}

private struct TestAuthenticator: BiometricAuthenticator {
  enum Result: Equatable, Sendable {
    case success
    case failure
  }

  let result: Result

  func authenticate(reason: String) async throws {
    if result == .failure {
      throw VaultError.authenticationFailed
    }
  }
}
