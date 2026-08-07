import Foundation

enum BackupFormatError: Error, Equatable, Sendable {
  case unsupportedVersion
  case unsupportedKDF
  case invalidSalt
  case invalidNonce
  case invalidCiphertext
  case oversizedBackup
}

struct BackupEnvelope: Codable, Equatable, Sendable {
  static let currentVersion = 1
  static let kdfName = "PBKDF2-HMAC-SHA256"
  static let kdfIterations = 600_000
  static let saltLength = 16
  static let nonceLength = 12
  static let authenticationTagLength = 16
  static let maximumCiphertextLength = 64 * 1024 * 1024

  let formatVersion: Int
  let kdf: String
  let iterations: Int
  let salt: Data
  let nonce: Data
  let ciphertext: Data

  init(
    formatVersion: Int = Self.currentVersion,
    kdf: String = Self.kdfName,
    iterations: Int = Self.kdfIterations,
    salt: Data,
    nonce: Data,
    ciphertext: Data
  ) throws {
    guard formatVersion == Self.currentVersion else {
      throw BackupFormatError.unsupportedVersion
    }
    guard kdf == Self.kdfName, iterations == Self.kdfIterations else {
      throw BackupFormatError.unsupportedKDF
    }
    guard salt.count == Self.saltLength else {
      throw BackupFormatError.invalidSalt
    }
    guard nonce.count == Self.nonceLength else {
      throw BackupFormatError.invalidNonce
    }
    guard ciphertext.count >= Self.authenticationTagLength else {
      throw BackupFormatError.invalidCiphertext
    }
    guard ciphertext.count <= Self.maximumCiphertextLength else {
      throw BackupFormatError.oversizedBackup
    }

    self.formatVersion = formatVersion
    self.kdf = kdf
    self.iterations = iterations
    self.salt = salt
    self.nonce = nonce
    self.ciphertext = ciphertext
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      formatVersion: container.decode(Int.self, forKey: .formatVersion),
      kdf: container.decode(String.self, forKey: .kdf),
      iterations: container.decode(Int.self, forKey: .iterations),
      salt: container.decode(Data.self, forKey: .salt),
      nonce: container.decode(Data.self, forKey: .nonce),
      ciphertext: container.decode(Data.self, forKey: .ciphertext)
    )
  }
}
