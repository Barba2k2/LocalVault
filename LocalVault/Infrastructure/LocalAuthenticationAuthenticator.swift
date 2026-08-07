import Foundation
import LocalAuthentication

struct LocalAuthenticationAuthenticator: BiometricAuthenticator {
  func authenticate(reason: String) async throws {
    let context = LAContext()
    var policyError: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
      throw VaultError.authenticationUnavailable
    }

    do {
      try await context.evaluatePolicy(
        .deviceOwnerAuthentication,
        localizedReason: reason
      )
    } catch {
      throw VaultError.authenticationFailed
    }
  }
}
