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
}
