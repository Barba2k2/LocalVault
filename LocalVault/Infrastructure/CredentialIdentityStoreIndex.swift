import AuthenticationServices
import Foundation

/// Publishes only service host, username, and opaque record ID to the system index.
/// Passwords and all other vault fields remain in the encrypted shared container.
@MainActor
final class CredentialIdentityStoreIndex: CredentialIdentityIndex {
  private let store = ASCredentialIdentityStore.shared

  func reconcile(_ credentials: [Credential]) async throws {
    let identities = credentials.compactMap { credential -> ASPasswordCredentialIdentity? in
      guard let serviceIdentifier = credential.url?.host,
        !serviceIdentifier.isEmpty,
        !credential.username.isEmpty
      else {
        return nil
      }

      let service = ASCredentialServiceIdentifier(
        identifier: serviceIdentifier.lowercased(),
        type: .domain
      )
      return ASPasswordCredentialIdentity(
        serviceIdentifier: service,
        user: credential.username,
        recordIdentifier: credential.id.uuidString
      )
    }

    try await withCheckedThrowingContinuation { continuation in
      store.replaceCredentialIdentities(identities) { success, error in
        if success {
          continuation.resume()
        } else if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(
            throwing: NSError(
              domain: "CredentialIdentityStore",
              code: 1,
              userInfo: [NSLocalizedDescriptionKey: "Credential identity index update failed"]
            )
          )
        }
      }
    }
  }
}
