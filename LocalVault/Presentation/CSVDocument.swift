import SwiftUI
import UniformTypeIdentifiers

extension UTType {
  static let localVaultCSV = UTType.commaSeparatedText
}

struct CSVDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.commaSeparatedText, .plainText]

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
