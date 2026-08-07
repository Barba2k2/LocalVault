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
  private var scheduledLockTask: Task<Void, Never>?

  init(authenticator: any BiometricAuthenticator) {
    self.authenticator = authenticator
  }

  var isLocked: Bool {
    state != .unlocked
  }

  func unlock() async {
    guard state != .unlocked else { return }

    await authenticate()
  }

  func reauthenticate() async -> Bool {
    await authenticate()
    return state == .unlocked
  }

  private func authenticate() async {

    state = .unlocking
    do {
      try await authenticator.authenticate(reason: "Unlock your LocalVault")
      state = .unlocked
    } catch {
      state = .locked
    }
  }

  func lock() {
    scheduledLockTask?.cancel()
    scheduledLockTask = nil
    state = .locked
  }

  func scheduleLock(after seconds: TimeInterval) {
    scheduledLockTask?.cancel()
    guard seconds > 0 else {
      lock()
      return
    }

    scheduledLockTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      self?.lock()
    }
  }

  func cancelScheduledLock() {
    scheduledLockTask?.cancel()
    scheduledLockTask = nil
  }
}
