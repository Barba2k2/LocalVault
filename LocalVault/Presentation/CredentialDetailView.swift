import SwiftUI

struct CredentialDetailView: View {
  @EnvironmentObject private var viewModel: CredentialListViewModel
  @Environment(\.dismiss) private var dismiss
  @StateObject private var clipboard = ClipboardManager()

  let credential: Credential

  @State private var isPasswordVisible = false
  @State private var isEditing = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    List {
      Section("Credential") {
        LabeledContent("Title", value: credential.title)
        HStack {
          LabeledContent("Username", value: credential.username.isEmpty ? "—" : credential.username)
          if !credential.username.isEmpty {
            copyButton(for: "username", value: credential.username)
          }
        }
        HStack {
          Text("Password")
          Spacer()
          Text(isPasswordVisible ? credential.password : String(repeating: "•", count: 8))
            .privacySensitive()
          if !credential.password.isEmpty {
            copyButton(for: "password", value: credential.password)
          }
          Button(isPasswordVisible ? "Hide" : "Show") {
            isPasswordVisible.toggle()
          }
          .buttonStyle(.borderless)
          .accessibilityHint("Controls whether the password is visible")
        }
        if let url = credential.url {
          Link(url.absoluteString, destination: url)
        }
      }

      if !credential.notes.isEmpty || credential.category != nil {
        Section("Details") {
          if let category = credential.category, !category.isEmpty {
            LabeledContent("Category", value: category)
          }
          if !credential.notes.isEmpty {
            Text(credential.notes)
          }
        }
      }
    }
    .navigationTitle(credential.title)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button("Edit", systemImage: "pencil") { isEditing = true }
          Button("Delete", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Credential actions")
      }
    }
    .sheet(isPresented: $isEditing) {
      CredentialEditorView(credential: credential)
        .environmentObject(viewModel)
    }
    .confirmationDialog(
      "Delete this credential?",
      isPresented: $showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task {
          if await viewModel.delete(id: credential.id) {
            dismiss()
          }
        }
      }
    }
  }

  private func copyButton(for field: String, value: String) -> some View {
    Button(clipboard.copiedField == field ? "Copied" : "Copy") {
      clipboard.copy(value, field: field)
    }
    .buttonStyle(.borderless)
    .accessibilityLabel("Copy \(field)")
    .accessibilityHint("Copies the \(field) to the clipboard and clears it automatically")
  }
}
