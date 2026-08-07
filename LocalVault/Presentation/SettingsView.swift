import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var viewModel: CredentialListViewModel
  @EnvironmentObject private var lockController: VaultLockController
  @AppStorage("autoLockSeconds") private var autoLockSeconds: Double = 0
  @AppStorage("hasCompletedVaultOnboarding") private var hasCompletedOnboarding = true

  @State private var showDeleteConfirmation = false
  @State private var isDeleting = false

  var body: some View {
    NavigationStack {
      Form {
        Section("Security") {
          Picker("Auto-lock", selection: $autoLockSeconds) {
            Text("Immediately").tag(0.0)
            Text("After 1 minute").tag(60.0)
            Text("After 5 minutes").tag(300.0)
            Text("After 15 minutes").tag(900.0)
          }
          Text(
            "The vault always locks when the app goes to the background. This setting controls the grace period."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }

        Section("Privacy") {
          Label("No account, cloud sync, or tracking", systemImage: "lock.shield")
          Text(
            "LocalVault stores encrypted data on this device. Backup and import actions will appear here when available."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }

        Section("Danger Zone") {
          Button("Delete Entire Vault", role: .destructive) {
            showDeleteConfirmation = true
          }
          .disabled(isDeleting)
          Text(
            "This removes all credentials and the local encryption key. Without a backup, the data cannot be recovered."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .confirmationDialog(
        "Delete the entire vault?",
        isPresented: $showDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Authenticate and Delete", role: .destructive) {
          Task {
            isDeleting = true
            if await lockController.reauthenticate(), await viewModel.deleteVault() {
              hasCompletedOnboarding = false
              dismiss()
            }
            isDeleting = false
          }
        }
      } message: {
        Text("This action permanently deletes every credential and its encryption key.")
      }
    }
  }
}
