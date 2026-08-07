import Foundation

@MainActor
protocol CredentialIdentityIndex {
  func reconcile(_ credentials: [Credential]) async throws
}

@MainActor
struct NoopCredentialIdentityIndex: CredentialIdentityIndex {
  func reconcile(_ credentials: [Credential]) async throws {}
}
