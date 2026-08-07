import Combine
import Foundation

@MainActor
final class CredentialListViewModel: ObservableObject {
  @Published var query = ""
  @Published private(set) var credentials: [Credential] = []
  @Published private(set) var isLoading = false
  @Published private(set) var error: VaultError?

  private let repository: any CredentialRepository

  init(repository: any CredentialRepository) {
    self.repository = repository
  }

  var visibleCredentials: [Credential] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: .diacriticInsensitive, locale: .current)
      .lowercased()

    return
      credentials
      .filter { credential in
        guard !normalizedQuery.isEmpty else { return true }

        return [
          credential.title,
          credential.username,
          credential.url?.absoluteString ?? "",
          credential.category ?? "",
        ].contains { field in
          field.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .contains(normalizedQuery)
        }
      }
      .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
  }

  func refresh() async {
    guard !isLoading else { return }

    isLoading = true
    error = nil
    defer { isLoading = false }

    do {
      credentials = try await repository.list()
    } catch let vaultError as VaultError {
      error = vaultError
    } catch {
      self.error = .invalidStoredData
    }
  }
}
