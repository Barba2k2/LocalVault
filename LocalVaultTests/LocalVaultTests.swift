import Foundation
import Testing

@testable import LocalVault

struct LocalVaultTests {
  @MainActor
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

  @Test func passwordGeneratorHonorsLengthAndCharacterSets() throws {
    let password = try PasswordGenerator().generate(
      length: 24,
      includeUppercase: false,
      includeLowercase: false,
      includeNumbers: true,
      includeSymbols: false
    )

    #expect(password.count == 24)
    #expect(password.allSatisfy { PasswordGenerator.numbers.contains($0) })
  }

  @Test func passwordGeneratorRejectsEmptyCharacterSet() {
    var rejected = false
    do {
      _ = try PasswordGenerator().generate(
        length: 20,
        includeUppercase: false,
        includeLowercase: false,
        includeNumbers: false,
        includeSymbols: false
      )
    } catch PasswordGeneratorError.emptyCharacterSet {
      rejected = true
    } catch {
      rejected = false
    }

    #expect(rejected)
  }

  @Test func backupEnvelopeRoundTripsAndExcludesPassword() throws {
    let envelope = try BackupEnvelope(
      salt: Data(repeating: 0x01, count: BackupEnvelope.saltLength),
      nonce: Data(repeating: 0x02, count: BackupEnvelope.nonceLength),
      ciphertext: Data(repeating: 0x03, count: BackupEnvelope.authenticationTagLength)
    )
    let data = try JSONEncoder().encode(envelope)
    let decoded = try JSONDecoder().decode(BackupEnvelope.self, from: data)

    #expect(decoded == envelope)
    #expect(String(data: data, encoding: .utf8)?.contains("password") == false)
    #expect(envelope.kdf == "PBKDF2-HMAC-SHA256")
    #expect(envelope.iterations == 600_000)
  }

  @Test func backupEnvelopeRejectsMalformedCryptographicFields() {
    var rejectedNonce = false
    do {
      _ = try BackupEnvelope(
        salt: Data(repeating: 0x01, count: BackupEnvelope.saltLength),
        nonce: Data(repeating: 0x02, count: 8),
        ciphertext: Data(repeating: 0x03, count: BackupEnvelope.authenticationTagLength)
      )
    } catch BackupFormatError.invalidNonce {
      rejectedNonce = true
    } catch {
      rejectedNonce = false
    }

    #expect(rejectedNonce)
  }

  @Test func encryptedBackupRoundTripsCredentials() throws {
    let credentials = [Credential(title: "Example", password: "secret")]
    let service = EncryptedBackupService()
    let backup = try service.makeBackup(from: credentials, password: "correct horse")

    #expect(try service.restoreCredentials(from: backup, password: "correct horse") == credentials)
    #expect(String(data: backup, encoding: .utf8)?.contains("secret") == false)
  }

  @Test func encryptedBackupRejectsWrongPassword() throws {
    let service = EncryptedBackupService()
    let backup = try service.makeBackup(
      from: [Credential(title: "Example", password: "secret")],
      password: "correct horse"
    )
    var rejected = false
    do {
      _ = try service.restoreCredentials(from: backup, password: "wrong horse")
    } catch BackupServiceError.authenticationFailed {
      rejected = true
    } catch {
      rejected = false
    }

    #expect(rejected)
  }

  @Test func csvRoundTripsEscapedFieldsAndReportsInvalidRows() throws {
    let service = CSVServiceImpl()
    let csv = try service.export([
      Credential(
        title: "Example, Inc.", username: "user", password: "p\"ass", notes: "line 1\nline 2")
    ])
    let result = try service.preview(
      csv + Data("\n,missing,password,,notes,category\r\n".utf8)
    )
    #expect(result.invalidRows.count == 1)
    #expect(result.credentials.count == 1)
    #expect(result.credentials.first?.title == "Example, Inc.")
    #expect(result.credentials.first?.password == "p\"ass")
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

  @MainActor
  @Test func credentialListSortsAndSearchesWithoutExposingPassword() async {
    let credentials = [
      Credential(
        title: "Zebra",
        username: "z@example.com",
        password: "hidden-z",
        url: URL(string: "https://zebra.example"),
        category: "Personal"
      ),
      Credential(
        title: "Alpha",
        username: "a@example.com",
        password: "hidden-a",
        url: URL(string: "https://work.example"),
        category: "Work"
      ),
    ]
    let viewModel = CredentialListViewModel(
      repository: TestCredentialRepository(credentials: credentials))

    await viewModel.refresh()
    #expect(viewModel.visibleCredentials.map(\.title) == ["Alpha", "Zebra"])
    #expect(viewModel.visibleCredentials.allSatisfy { !$0.password.isEmpty })

    viewModel.query = "work"
    #expect(viewModel.visibleCredentials.map(\.title) == ["Alpha"])
  }

  @MainActor
  @Test func restoreBackupReplacesVaultAfterValidation() async throws {
    let previous = Credential(title: "Previous", password: "old")
    let restored = Credential(title: "Restored", password: "new")
    let repository = TestCredentialRepository(credentials: [previous])
    let viewModel = CredentialListViewModel(repository: repository)
    let backup = try EncryptedBackupService().makeBackup(
      from: [restored],
      password: "correct horse"
    )

    let count = try await viewModel.restoreBackup(backup, password: "correct horse")
    let current = try await repository.list()

    #expect(count == 1)
    #expect(current == [restored])
  }

  @MainActor
  @Test func failedBackupReplacementLeavesVaultUntouched() async throws {
    let previous = Credential(title: "Previous", password: "old")
    let restored = Credential(title: "Restored", password: "new")
    let repository = TestCredentialRepository(credentials: [previous], failsReplacement: true)
    let viewModel = CredentialListViewModel(repository: repository)
    let backup = try EncryptedBackupService().makeBackup(
      from: [restored],
      password: "correct horse"
    )

    var failed = false
    do {
      _ = try await viewModel.restoreBackup(backup, password: "correct horse")
    } catch VaultError.persistenceFailure {
      failed = true
    }

    let current = try await repository.list()
    #expect(failed)
    #expect(current == [previous])
  }

  @MainActor
  @Test func credentialListSearchesFiveThousandCredentialsWithinTarget() async {
    let credentials = (0..<5_000).map { index in
      Credential(
        title: "Credential \(index)",
        username: "user\(index)",
        password: "secret\(index)"
      )
    }
    let repository = TestCredentialRepository(credentials: credentials)
    let viewModel = CredentialListViewModel(repository: repository)

    await viewModel.refresh()
    let start = ContinuousClock.now
    viewModel.query = "Credential 4999"
    let matches = viewModel.visibleCredentials
    let elapsed = start.duration(to: .now)

    #expect(matches.count == 1)
    #expect(matches.first?.title == "Credential 4999")
    #expect(elapsed < .milliseconds(250))
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

private actor TestCredentialRepository: CredentialRepository {
  private var credentials: [Credential]
  private let failsReplacement: Bool

  init(credentials: [Credential], failsReplacement: Bool = false) {
    self.credentials = credentials
    self.failsReplacement = failsReplacement
  }

  func initialize() async throws {}

  func deleteVault() async throws {}

  func list() async throws -> [Credential] {
    credentials
  }

  func find(id: UUID) async throws -> Credential? {
    credentials.first { $0.id == id }
  }

  func save(_ credential: Credential) async throws {}

  func replaceAll(_ credentials: [Credential]) async throws {
    if failsReplacement {
      throw VaultError.persistenceFailure
    }
    self.credentials = credentials
  }

  func delete(id: UUID) async throws {}
}
