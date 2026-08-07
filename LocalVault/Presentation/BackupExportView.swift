import SwiftUI

struct BackupExportView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var viewModel: CredentialListViewModel

  @State private var password = ""
  @State private var confirmation = ""
  @State private var document: BackupDocument?
  @State private var isExporting = false
  @State private var isPreparing = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Backup password") {
          SecureField("Password", text: $password)
          SecureField("Confirm password", text: $confirmation)
          Text("This password is not recoverable. Keep it separate from the device.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        if let errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }

        Section {
          Button("Export Encrypted Backup", systemImage: "arrow.down.doc") {
            Task { await prepareExport() }
          }
          .disabled(isPreparing || password.count < 8 || password != confirmation)
        }
      }
      .navigationTitle("Export Backup")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .fileExporter(
        isPresented: $isExporting,
        document: document,
        contentType: .localVaultBackup,
        defaultFilename: "LocalVault-Backup.localvault"
      ) { result in
        if case .failure = result {
          errorMessage = "The backup could not be exported."
        }
      }
    }
  }

  private func prepareExport() async {
    guard password == confirmation, password.count >= 8 else {
      errorMessage = "Use a password with at least 8 characters and confirm it."
      return
    }

    isPreparing = true
    defer { isPreparing = false }
    do {
      document = BackupDocument(data: try await viewModel.makeBackup(password: password))
      isExporting = true
      password.removeAll()
      confirmation.removeAll()
    } catch {
      errorMessage = "The backup could not be created."
    }
  }
}
