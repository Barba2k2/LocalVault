import SwiftUI
import UniformTypeIdentifiers

extension UTType {
  static let localVaultBackup = UTType(exportedAs: "com.barba.localvault.backup")
}

struct BackupDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.localVaultBackup, .data]

  let data: Data

  init(data: Data = Data()) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
