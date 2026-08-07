import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var viewModel: CredentialListViewModel

  @State private var showImporter = false
  @State private var preview: CSVImportResult?
  @State private var showConfirmation = false
  @State private var errorMessage: String?
  @State private var isImporting = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Image(systemName: "arrow.up.doc")
          .font(.system(size: 48))
          .foregroundStyle(.tint)
        Text("Import credentials from CSV")
          .font(.title2.bold())
        Text("CSV is readable by third parties. Review the preview before importing.")
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
        Button("Choose CSV", systemImage: "folder") {
          showImporter = true
        }
        .buttonStyle(.borderedProminent)

        if let preview {
          Form {
            Section("Mapping") {
              Text(preview.headers.joined(separator: ", "))
                .font(.footnote.monospaced())
            }
            Section("Preview") {
              LabeledContent("Valid", value: "\(preview.credentials.count)")
              LabeledContent("Invalid", value: "\(preview.invalidRows.count)")
              LabeledContent("Ignored", value: "\(preview.ignoredRows.count)")
            }
            if !preview.credentials.isEmpty {
              Section {
                Button("Import Valid Credentials") {
                  showConfirmation = true
                }
                .disabled(isImporting)
              }
            }
          }
        }
        if let errorMessage {
          Text(errorMessage).foregroundStyle(.red)
        }
      }
      .padding(24)
      .navigationTitle("Import CSV")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
      .fileImporter(
        isPresented: $showImporter,
        allowedContentTypes: [.commaSeparatedText, .plainText]
      ) { result in
        switch result {
        case .success(let url):
          do {
            preview = try viewModel.previewCSV(Data(contentsOf: url))
            errorMessage = nil
          } catch {
            errorMessage = "The CSV could not be read or is missing a title column."
          }
        case .failure:
          errorMessage = "The CSV could not be opened."
        }
      }
      .confirmationDialog(
        "Import valid credentials?", isPresented: $showConfirmation, titleVisibility: .visible
      ) {
        Button("Import", role: .destructive) {
          Task {
            guard let preview else { return }
            isImporting = true
            do {
              try await viewModel.importCredentials(preview.credentials)
              dismiss()
            } catch {
              errorMessage = "Some credentials could not be imported."
            }
            isImporting = false
          }
        }
      } message: {
        Text(
          "Only valid rows will be added. Existing credentials with different IDs are added as new records."
        )
      }
    }
  }
}
