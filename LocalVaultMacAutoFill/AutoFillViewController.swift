import AuthenticationServices
import Foundation

final class AutoFillViewController: ASCredentialProviderViewController {
  private let appGroup = "group.com.barba.localvault"

  private lazy var repository: EncryptedCredentialRepository = {
    let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    )
    let vaultURL = (container ?? FileManager.default.temporaryDirectory)
      .appendingPathComponent("LocalVault", isDirectory: true)
      .appendingPathComponent("macos-vault.localvault")
    return EncryptedCredentialRepository(
      fileURL: vaultURL,
      keyStore: KeychainVaultKeyStore(
        service: "com.barba.localvault.macos",
        accessGroup: appGroup
      )
    )
  }()

  override func prepareInterfaceForExtensionConfiguration() {
    extensionContext.completeExtensionConfigurationRequest()
  }

  override func provideCredentialWithoutUserInteraction(
    for credentialIdentity: ASPasswordCredentialIdentity
  ) {
    provideCredential(for: credentialIdentity)
  }

  override func prepareInterfaceToProvideCredential(
    for credentialIdentity: ASPasswordCredentialIdentity
  ) {
    provideCredential(for: credentialIdentity)
  }

  private func provideCredential(for identity: ASPasswordCredentialIdentity) {
    guard let recordIdentifier = identity.recordIdentifier,
      let id = UUID(uuidString: recordIdentifier)
    else {
      cancel(with: .credentialIdentityNotFound)
      return
    }

    Task {
      do {
        guard let credential = try await repository.find(id: id) else {
          cancel(with: .credentialIdentityNotFound)
          return
        }
        let password = ASPasswordCredential(
          user: credential.username,
          password: credential.password
        )
        extensionContext.completeRequest(withSelectedCredential: password)
      } catch {
        cancel(with: .userInteractionRequired)
      }
    }
  }

  private func cancel(with code: ASExtensionError.Code) {
    extensionContext.cancelRequest(
      withError: NSError(domain: ASExtensionErrorDomain, code: code.rawValue)
    )
  }
}
