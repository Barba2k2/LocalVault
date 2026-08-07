import CommonCrypto
import CryptoKit
import Foundation
import Security

enum BackupServiceError: Error, Equatable, Sendable {
  case invalidPassword
  case randomSourceFailure
  case invalidBackup
  case authenticationFailed
  case encryptionFailure
}

struct EncryptedBackupService: BackupService, Sendable {
  private static let keyLength = 32

  func makeBackup(from credentials: [Credential], password: String) throws -> Data {
    let plaintext: Data
    do {
      plaintext = try JSONEncoder().encode(credentials)
    } catch {
      throw BackupServiceError.encryptionFailure
    }

    var nonceBytes = Data(repeating: 0, count: BackupEnvelope.nonceLength)
    let nonceStatus = nonceBytes.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
    }
    guard nonceStatus == errSecSuccess else {
      throw BackupServiceError.randomSourceFailure
    }

    var salt = Data(repeating: 0, count: BackupEnvelope.saltLength)
    let saltStatus = salt.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
    }
    guard saltStatus == errSecSuccess else {
      throw BackupServiceError.randomSourceFailure
    }
    let key = try deriveKey(password: password, salt: salt)

    let sealedBox: AES.GCM.SealedBox
    do {
      let nonce = try AES.GCM.Nonce(data: nonceBytes)
      sealedBox = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), nonce: nonce)
    } catch {
      throw BackupServiceError.encryptionFailure
    }

    var ciphertext = sealedBox.ciphertext
    ciphertext.append(sealedBox.tag)
    let envelope = try BackupEnvelope(
      salt: salt,
      nonce: nonceBytes,
      ciphertext: ciphertext
    )

    do {
      return try JSONEncoder().encode(envelope)
    } catch {
      throw BackupServiceError.encryptionFailure
    }
  }

  func restoreCredentials(from backup: Data, password: String) throws -> [Credential] {
    guard !password.isEmpty else { throw BackupServiceError.invalidPassword }

    let envelope: BackupEnvelope
    do {
      envelope = try JSONDecoder().decode(BackupEnvelope.self, from: backup)
    } catch {
      throw BackupServiceError.invalidBackup
    }

    let key = try deriveKey(password: password, salt: envelope.salt)
    let tagIndex = envelope.ciphertext.index(
      envelope.ciphertext.endIndex,
      offsetBy: -BackupEnvelope.authenticationTagLength
    )
    let ciphertext = envelope.ciphertext[..<tagIndex]
    let tag = envelope.ciphertext[tagIndex...]

    do {
      let nonce = try AES.GCM.Nonce(data: envelope.nonce)
      let sealedBox = try AES.GCM.SealedBox(
        nonce: nonce,
        ciphertext: ciphertext,
        tag: tag
      )
      let plaintext = try AES.GCM.open(sealedBox, using: SymmetricKey(data: key))
      return try JSONDecoder().decode([Credential].self, from: plaintext)
    } catch DecodingError.dataCorrupted, DecodingError.keyNotFound, DecodingError.typeMismatch,
      DecodingError.valueNotFound
    {
      throw BackupServiceError.invalidBackup
    } catch {
      throw BackupServiceError.authenticationFailed
    }
  }

  private func deriveKey(password: String, salt: Data = Data()) throws -> Data {
    guard password.count >= 8 else {
      throw BackupServiceError.invalidPassword
    }

    let passwordData = Data(password.utf8)
    var key = Data(repeating: 0, count: Self.keyLength)
    let status = passwordData.withUnsafeBytes { passwordBuffer in
      salt.withUnsafeBytes { saltBuffer in
        key.withUnsafeMutableBytes { keyBuffer in
          CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordBuffer.bindMemory(to: Int8.self).baseAddress,
            passwordBuffer.count,
            saltBuffer.bindMemory(to: UInt8.self).baseAddress,
            saltBuffer.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            UInt32(BackupEnvelope.kdfIterations),
            keyBuffer.bindMemory(to: UInt8.self).baseAddress,
            keyBuffer.count
          )
        }
      }
    }
    guard status == kCCSuccess else {
      throw BackupServiceError.encryptionFailure
    }
    return key
  }
}
