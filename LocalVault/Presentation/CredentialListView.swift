import SwiftUI

struct CredentialListView: View {
  @EnvironmentObject private var viewModel: CredentialListViewModel
  @State private var showNewCredential = false

  var body: some View {
    NavigationSplitView {
      Group {
        if viewModel.isLoading {
          ProgressView("Loading credentials…")
        } else if viewModel.credentials.isEmpty {
          VStack(spacing: 16) {
            ContentUnavailableView(
              "No Credentials",
              systemImage: "tray",
              description: Text("Your local vault is empty.")
            )
            Button("Create Credential") {
              showNewCredential = true
            }
            .buttonStyle(.borderedProminent)
          }
        } else if viewModel.visibleCredentials.isEmpty {
          ContentUnavailableView.search(text: viewModel.query)
        } else {
          List(viewModel.visibleCredentials) { credential in
            NavigationLink(value: credential.id) {
              CredentialRow(credential: credential)
            }
          }
        }
      }
      .navigationTitle("LocalVault")
      .searchable(text: $viewModel.query, prompt: "Search credentials")
      .navigationDestination(for: UUID.self) { id in
        if let credential = viewModel.credentials.first(where: { $0.id == id }) {
          CredentialDetailView(credential: credential)
        }
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("New Credential", systemImage: "plus") {
            showNewCredential = true
          }
        }
      }
    } detail: {
      ContentUnavailableView(
        "Select a Credential",
        systemImage: "lock.shield",
        description: Text("Choose a credential to view its details.")
      )
    }
    .sheet(isPresented: $showNewCredential) {
      CredentialEditorView()
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
