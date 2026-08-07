import SwiftUI

struct CredentialListView: View {
  @EnvironmentObject private var viewModel: CredentialListViewModel

  var body: some View {
    NavigationSplitView {
      Group {
        if viewModel.isLoading {
          ProgressView("Loading credentials…")
        } else if viewModel.credentials.isEmpty {
          ContentUnavailableView(
            "No Credentials",
            systemImage: "tray",
            description: Text("Your local vault is empty.")
          )
        } else if viewModel.visibleCredentials.isEmpty {
          ContentUnavailableView.search(text: viewModel.query)
        } else {
          List(viewModel.visibleCredentials) { credential in
            CredentialRow(credential: credential)
          }
        }
      }
      .navigationTitle("LocalVault")
      .searchable(text: $viewModel.query, prompt: "Search credentials")
    } detail: {
      ContentUnavailableView(
        "Select a Credential",
        systemImage: "lock.shield",
        description: Text("Choose a credential to view its details.")
      )
    }
    .task {
      await viewModel.refresh()
    }
  }
}

private struct CredentialRow: View {
  let credential: Credential

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(credential.title)
        .font(.headline)
      if !credential.username.isEmpty {
        Text(credential.username)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      if let category = credential.category, !category.isEmpty {
        Text(category)
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .privacySensitive()
  }
}
