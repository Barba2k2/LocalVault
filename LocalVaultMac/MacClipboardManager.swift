import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class ClipboardManager: ObservableObject {
  @Published private(set) var copiedField: String?

  private var copyToken: UUID?
  private let expirationInterval: TimeInterval

  init(expirationInterval: TimeInterval = 30) {
    self.expirationInterval = expirationInterval
  }

  func copy(_ value: String, field: String) {
    guard !value.isEmpty else { return }

    let token = UUID()
    copyToken = token
    copiedField = field
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)

    let expiration = expirationInterval
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(expiration))
      guard let self, self.copyToken == token else { return }
      guard NSPasteboard.general.string(forType: .string) == value else {
        copiedField = nil
        copyToken = nil
        return
      }
      NSPasteboard.general.clearContents()
      copiedField = nil
      copyToken = nil
    }
  }
}
