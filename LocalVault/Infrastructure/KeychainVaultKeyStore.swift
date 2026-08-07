import Foundation
import Security

enum KeychainStoreError: Error, Equatable, Sendable {
  case unexpectedStatus(OSStatus)
  case invalidStoredData
}

struct KeychainVaultKeyStore: KeychainStore {
  private static let keyLength = 32

  private let service: String
  private let account: String

  init(
    service: String = Bundle.main.bundleIdentifier ?? "com.barba.localvault",
    account: String = "vault-key"
  ) {
    self.service = service
    self.account = account
  }

  func readKey() throws -> Data? {
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query(returnData: true) as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data, data.count == Self.keyLength else {
        throw KeychainStoreError.invalidStoredData
      }
      return data
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainStoreError.unexpectedStatus(status)
    }
  }

  func createKeyIfNeeded() throws -> Data {
    if let existingKey = try readKey() {
      return existingKey
    }

    var bytes = Data(repeating: 0, count: Self.keyLength)
    let randomStatus = bytes.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
    }

    guard randomStatus == errSecSuccess else {
      throw KeychainStoreError.unexpectedStatus(randomStatus)
    }

    var attributes = baseQuery()
    attributes[kSecValueData] = bytes
    attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked

    let status = SecItemAdd(attributes as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return bytes
    case errSecDuplicateItem:
      guard let existingKey = try readKey() else {
        throw KeychainStoreError.unexpectedStatus(status)
      }
      return existingKey
    default:
      throw KeychainStoreError.unexpectedStatus(status)
    }
  }

  func deleteKey() throws {
    let status = SecItemDelete(baseQuery() as CFDictionary)

    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainStoreError.unexpectedStatus(status)
    }
  }

  private func baseQuery() -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
    ]
  }

  private func query(returnData: Bool) -> [CFString: Any] {
    var query = baseQuery()
    query[kSecReturnData] = returnData
    query[kSecMatchLimit] = kSecMatchLimitOne
    return query
  }
}
