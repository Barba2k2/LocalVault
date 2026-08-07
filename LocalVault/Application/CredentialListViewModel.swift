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

  func save(_ credential: Credential) async -> Bool {
    let normalizedTitle = credential.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedTitle.isEmpty else {
      error = .invalidCredentialTitle
      return false
    }

    let isExisting = credentials.contains { $0.id == credential.id }
    let normalizedCredential = Credential(
      id: credential.id,
      title: normalizedTitle,
      username: credential.username,
      password: credential.password,
      url: credential.url,
      notes: credential.notes,
      category: credential.category,
      createdAt: credential.createdAt,
      updatedAt: isExisting ? Date() : credential.updatedAt
    )

    do {
      try await repository.save(normalizedCredential)
      await refresh()
      return true
    } catch let vaultError as VaultError {
      error = vaultError
    } catch {
      self.error = .persistenceFailure
    }
    return false
  }

  func delete(id: UUID) async -> Bool {
    do {
      try await repository.delete(id: id)
      await refresh()
      return true
    } catch let vaultError as VaultError {
      error = vaultError
    } catch {
      self.error = .persistenceFailure
    }
    return false
  }
}
