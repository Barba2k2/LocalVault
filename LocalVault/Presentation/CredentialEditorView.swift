import SwiftUI

struct CredentialEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var viewModel: CredentialListViewModel

  @State private var credential: Credential
  @State private var isSaving = false

  private let isNew: Bool

  init(credential: Credential? = nil) {
    let value = credential ?? Credential(title: "")
    _credential = State(initialValue: value)
    isNew = credential == nil
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Credential") {
          TextField("Title", text: $credential.title)
          TextField("Username", text: $credential.username)
          SecureField("Password", text: $credential.password)
          TextField(
            "Website",
            text: Binding(
              get: { credential.url?.absoluteString ?? "" },
              set: { credential.url = URL(string: $0) }
            ))
        }

        Section("Details") {
          TextField(
            "Category",
            text: Binding(
              get: { credential.category ?? "" },
              set: { credential.category = $0.isEmpty ? nil : $0 }
            ))
          TextField("Notes", text: $credential.notes, axis: .vertical)
        }
      }
      .navigationTitle(isNew ? "New Credential" : "Edit Credential")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              isSaving = true
              if await viewModel.save(credential) {
                dismiss()
              }
              isSaving = false
            }
          }
          .disabled(
            isSaving || credential.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
