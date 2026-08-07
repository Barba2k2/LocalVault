import Combine
import UIKit
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
    let expiration = expirationInterval
    copyToken = token
    copiedField = field
    UIPasteboard.general.setItems(
      [[UTType.plainText.identifier: value]],
      options: [.expirationDate: Date(timeIntervalSinceNow: expiration)]
    )

    Task { [weak self] in
      try? await Task.sleep(for: .seconds(expiration))
      guard let self, self.copyToken == token else { return }
      UIPasteboard.general.items = []
      copiedField = nil
      copyToken = nil
    }
  }
}
