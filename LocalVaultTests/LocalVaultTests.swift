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
}
