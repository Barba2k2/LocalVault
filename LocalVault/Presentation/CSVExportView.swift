import SwiftUI

struct CSVExportView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var viewModel: CredentialListViewModel
  @EnvironmentObject private var lockController: VaultLockController

  @State private var document: CSVDocument?
  @State private var isExporting = false
  @State private var showConfirmation = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Image(systemName: "doc.plaintext")
          .font(.system(size: 48))
          .foregroundStyle(.tint)
        Text("CSV is not encrypted")
          .font(.title2.bold())
        Text(
          "Anyone with the exported file can read every credential. Use encrypted backup for portability whenever possible."
        )
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        if let errorMessage {
          Text(errorMessage).foregroundStyle(.red)
        }
        Button("Authenticate and Export CSV", systemImage: "arrow.down.doc") {
          showConfirmation = true
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(32)
      .navigationTitle("Export CSV")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .confirmationDialog(
        "Export readable CSV?", isPresented: $showConfirmation, titleVisibility: .visible
      ) {
        Button("Authenticate and Export", role: .destructive) {
          Task { await export() }
        }
      } message: {
        Text("The file contains unencrypted usernames, passwords, and notes.")
      }
      .fileExporter(
        isPresented: $isExporting,
        document: document,
        contentType: .localVaultCSV,
        defaultFilename: "LocalVault-Credentials.csv"
      ) { result in
        if case .failure = result {
          errorMessage = "The CSV could not be exported."
        }
      }
    }
  }

  private func export() async {
    guard await lockController.reauthenticate() else {
      errorMessage = "Authentication failed."
      return
    }
    do {
      document = CSVDocument(data: try await viewModel.exportCSV())
      isExporting = true
    } catch {
      errorMessage = "The CSV could not be created."
    }
  }
}
