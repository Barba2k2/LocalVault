import Combine
import Foundation

enum VaultLockState: Equatable, Sendable {
  case locked
  case unlocking
  case unlocked
}

@MainActor
final class VaultLockController: ObservableObject {
  @Published private(set) var state: VaultLockState = .locked

  private let authenticator: any BiometricAuthenticator

  init(authenticator: any BiometricAuthenticator) {
    self.authenticator = authenticator
  }

  var isLocked: Bool {
    state != .unlocked
  }

  func unlock() async {
    guard state != .unlocked else { return }

    state = .unlocking
    do {
      try await authenticator.authenticate(reason: "Unlock your LocalVault")
      state = .unlocked
    } catch {
      state = .locked
    }
  }

  func lock() {
    state = .locked
  }
}
