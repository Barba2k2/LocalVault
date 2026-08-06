import CryptoKit
import Foundation

struct CryptoKitVaultCryptoService: VaultCryptoService {
  private static let keyLength = 32

  func encrypt(_ plaintext: Data, using key: Data) throws -> Data {
    let symmetricKey = try makeKey(from: key)
    let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey)

    guard let combined = sealedBox.combined else {
      throw VaultError.encryptionFailed
    }

    return combined
  }

  func decrypt(_ ciphertext: Data, using key: Data) throws -> Data {
    let symmetricKey = try makeKey(from: key)
    let sealedBox: AES.GCM.SealedBox

    do {
      sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
    } catch {
      throw VaultError.corruptedCiphertext
    }

    do {
      return try AES.GCM.open(sealedBox, using: symmetricKey)
    } catch {
      throw VaultError.authenticationFailed
    }
  }

  private func makeKey(from data: Data) throws -> SymmetricKey {
    guard data.count == Self.keyLength else {
      throw VaultError.invalidKeyLength
    }

    return SymmetricKey(data: data)
  }
}
