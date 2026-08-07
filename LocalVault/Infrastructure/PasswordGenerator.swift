import Foundation
import Security

enum PasswordGeneratorError: Error, Equatable, Sendable {
  case invalidLength
  case emptyCharacterSet
  case randomSourceFailure
}

struct PasswordGenerator: Sendable {
  static let uppercase = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
  static let lowercase = Array("abcdefghijkmnopqrstuvwxyz")
  static let numbers = Array("23456789")
  static let symbols = Array("!@#$%^&*()-_=+[]{};:,.?/")

  func generate(
    length: Int,
    includeUppercase: Bool,
    includeLowercase: Bool,
    includeNumbers: Bool,
    includeSymbols: Bool
  ) throws -> String {
    guard (8...128).contains(length) else {
      throw PasswordGeneratorError.invalidLength
    }

    var characters = [Character]()
    if includeUppercase { characters.append(contentsOf: Self.uppercase) }
    if includeLowercase { characters.append(contentsOf: Self.lowercase) }
    if includeNumbers { characters.append(contentsOf: Self.numbers) }
    if includeSymbols { characters.append(contentsOf: Self.symbols) }
    guard !characters.isEmpty else {
      throw PasswordGeneratorError.emptyCharacterSet
    }

    let count = characters.count
    let limit = UInt8.max - (UInt8.max % UInt8(count))
    var result = String()
    result.reserveCapacity(length)

    while result.count < length {
      var byte: UInt8 = 0
      let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
      guard status == errSecSuccess else {
        throw PasswordGeneratorError.randomSourceFailure
      }
      guard byte < limit else { continue }
      result.append(characters[Int(byte) % count])
    }

    return result
  }
}
