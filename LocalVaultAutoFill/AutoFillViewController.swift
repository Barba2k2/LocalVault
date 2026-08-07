import AuthenticationServices
import Foundation

final class AutoFillViewController: ASCredentialProviderViewController {
  private let authenticator = LocalAuthenticationAuthenticator()
  private lazy var repository: EncryptedCredentialRepository = {
    EncryptedCredentialRepository(
      fileURL: SharedVaultConfiguration.iOSVaultURL(),
      keyStore: KeychainVaultKeyStore(
        service: SharedVaultConfiguration.keychainService,
        accessGroup: SharedVaultConfiguration.keychainAccessGroup
      )
    )
  }()

  private var matchingCredentials: [Credential] = []

  override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
    Task { @MainActor in
      matchingCredentials = (try? await repository.list())?.filter { credential in
        guard let host = credential.url?.host?.lowercased() else { return false }
        return serviceIdentifiers.isEmpty
          || serviceIdentifiers.contains { identifier in
            let requested = identifier.identifier.lowercased()
            return host == requested || host.hasSuffix(".\(requested)")
          }
      } ?? []
    }
  }

  override func provideCredentialWithoutUserInteraction(for request: any ASCredentialRequest) {
    guard let identity = request.credentialIdentity as? ASPasswordCredentialIdentity else {
      cancel(with: .credentialIdentityNotFound)
      return
    }

    provideCredential(for: identity, authenticate: false)
  }

  override func prepareInterfaceToProvideCredential(for request: any ASCredentialRequest) {
    guard let identity = request.credentialIdentity as? ASPasswordCredentialIdentity else {
      cancel(with: .credentialIdentityNotFound)
      return
    }

    provideCredential(for: identity, authenticate: true)
  }

  override func prepareInterfaceForExtensionConfiguration() {
    extensionContext.completeExtensionConfigurationRequest()
  }

  private func provideCredential(
    for identity: ASPasswordCredentialIdentity,
    authenticate: Bool
  ) {
    guard let recordIdentifier = identity.recordIdentifier,
      let id = UUID(uuidString: recordIdentifier)
    else {
      cancel(with: .credentialIdentityNotFound)
      return
    }

    Task { @MainActor in
      do {
        if authenticate {
          try await authenticator.authenticate(reason: "Unlock LocalVault to fill this credential")
        } else {
          cancel(with: .userInteractionRequired)
          return
        }

        guard let credential = try await repository.find(id: id) else {
          cancel(with: .credentialIdentityNotFound)
          return
        }

        let password = ASPasswordCredential(
          user: credential.username,
          password: credential.password
        )
        extensionContext.completeRequest(withSelectedCredential: password, completionHandler: nil)
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
