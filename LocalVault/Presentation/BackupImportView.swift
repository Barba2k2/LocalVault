import SwiftUI
import UniformTypeIdentifiers

struct BackupImportView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var viewModel: CredentialListViewModel
  @EnvironmentObject private var lockController: VaultLockController

  @State private var backupData: Data?
  @State private var password = ""
  @State private var credentialCount: Int?
  @State private var isImporting = false
  @State private var showImporter = false
  @State private var showReplaceConfirmation = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Backup file") {
          Button("Choose .localvault file", systemImage: "doc") {
            showImporter = true
          }
          if let credentialCount {
            Label("Validated backup with \(credentialCount) credentials", systemImage: "checkmark.shield")
              .foregroundStyle(.green)
          } else {
            Text("The current vault is not changed until the file and password are validated.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Section("Backup password") {
          SecureField("Password", text: $password)
          Button("Validate Backup", systemImage: "checkmark.shield") {
            validateBackup()
          }
          .disabled(backupData == nil || password.isEmpty || isImporting)
        }

        if let errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }

        if credentialCount != nil {
          Section {
            Button("Replace Current Vault", systemImage: "arrow.triangle.2.circlepath", role: .destructive) {
              showReplaceConfirmation = true
            }
            .disabled(isImporting)
          } footer: {
            Text("This permanently replaces every credential in the current vault. The action requires authentication.")
          }
        }
      }
      .navigationTitle("Restore Backup")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .fileImporter(
        isPresented: $showImporter,
        allowedContentTypes: [.localVaultBackup, .data]
      ) { result in
        switch result {
        case .success(let url):
          do {
            backupData = try Data(contentsOf: url)
            credentialCount = nil
            errorMessage = nil
          } catch {
            errorMessage = "The backup file could not be read."
          }
        case .failure:
          errorMessage = "The backup file could not be selected."
        }
      }
      .confirmationDialog(
        "Replace the current vault?",
        isPresented: $showReplaceConfirmation,
        titleVisibility: .visible
      ) {
        Button("Authenticate and Replace", role: .destructive) {
          Task { await restoreBackup() }
        }
      } message: {
        Text("The current vault remains untouched if authentication or persistence fails.")
      }
    }
  }

  private func validateBackup() {
    guard let backupData else { return }
    do {
      credentialCount = try viewModel.previewBackup(backupData, password: password).count
      errorMessage = nil
    } catch {
      credentialCount = nil
      errorMessage = message(for: error)
    }
  }

  private func restoreBackup() async {
    guard let backupData else { return }
    isImporting = true
    defer { isImporting = false }

    guard await lockController.reauthenticate() else {
      errorMessage = "Authentication was cancelled. The current vault was not changed."
      return
    }

    do {
      _ = try await viewModel.restoreBackup(backupData, password: password)
      password.removeAll()
      dismiss()
    } catch {
      errorMessage = "Restore failed: \(message(for: error)) The current vault was not changed."
    }
  }

  private func message(for error: Error) -> String {
    switch error {
    case BackupServiceError.invalidPassword:
      return "Use a password with at least 8 characters."
    case BackupServiceError.authenticationFailed:
      return "The password is incorrect."
    case BackupServiceError.invalidBackup:
      return "The file is corrupted or has an unsupported format."
    case VaultError.invalidCredentialTitle:
      return "The backup contains an invalid credential title."
    default:
      return "The backup could not be validated."
    }
  }
}
