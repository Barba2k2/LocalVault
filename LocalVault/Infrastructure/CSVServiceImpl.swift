import Foundation

enum CSVServiceError: Error, Equatable, Sendable {
  case invalidEncoding
  case missingTitleColumn
  case emptyFile
}

struct CSVServiceImpl: CSVService, Sendable {
  private static let columns = ["title", "username", "password", "url", "notes", "category"]

  func export(_ credentials: [Credential]) throws -> Data {
    var lines = [Self.columns.joined(separator: ",")]
    lines.append(
      contentsOf: credentials.map { credential in
        [
          credential.title,
          credential.username,
          credential.password,
          credential.url?.absoluteString ?? "",
          credential.notes,
          credential.category ?? "",
        ].map(escape).joined(separator: ",")
      })
    guard let data = lines.joined(separator: "\r\n").appending("\r\n").data(using: .utf8) else {
      throw CSVServiceError.invalidEncoding
    }
    return data
  }

  func preview(_ data: Data) throws -> CSVImportResult {
    guard let text = String(data: data, encoding: .utf8) else {
      throw CSVServiceError.invalidEncoding
    }
    let rows = parseRows(text)
    guard let rawHeaders = rows.first, !rawHeaders.isEmpty else {
      throw CSVServiceError.emptyFile
    }

    let headers = rawHeaders.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    guard let titleIndex = headers.firstIndex(of: "title") else {
      throw CSVServiceError.missingTitleColumn
    }
    let usernameIndex = headers.firstIndex(of: "username")
    let passwordIndex = headers.firstIndex(of: "password")
    let urlIndex = headers.firstIndex(of: "url")
    let notesIndex = headers.firstIndex(of: "notes")
    let categoryIndex = headers.firstIndex(of: "category")

    var credentials = [Credential]()
    var invalidRows = [CSVImportIssue]()
    var ignoredRows = [Int]()
    for (offset, row) in rows.dropFirst().enumerated() {
      let rowNumber = offset + 2
      if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
        ignoredRows.append(rowNumber)
        continue
      }
      var normalizedRow = row
      while normalizedRow.count > headers.count, normalizedRow.last?.isEmpty == true {
        normalizedRow.removeLast()
      }
      guard normalizedRow.count == headers.count else {
        invalidRows.append(
          CSVImportIssue(
            row: rowNumber,
            reason: "Column count \(row.count) does not match the header \(headers.count)."))
        continue
      }
      let title = normalizedRow[titleIndex].trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else {
        invalidRows.append(CSVImportIssue(row: rowNumber, reason: "Title is required."))
        continue
      }
      let urlValue = value(at: urlIndex, in: normalizedRow)
      if !urlValue.isEmpty, URL(string: urlValue) == nil {
        invalidRows.append(CSVImportIssue(row: rowNumber, reason: "URL is invalid."))
        continue
      }
      credentials.append(
        Credential(
          title: title,
          username: value(at: usernameIndex, in: normalizedRow),
          password: value(at: passwordIndex, in: normalizedRow),
          url: urlValue.isEmpty ? nil : URL(string: urlValue),
          notes: value(at: notesIndex, in: normalizedRow),
          category: value(at: categoryIndex, in: normalizedRow).isEmpty
            ? nil : value(at: categoryIndex, in: normalizedRow)
        )
      )
    }

    return CSVImportResult(
      headers: headers,
      credentials: credentials,
      invalidRows: invalidRows,
      ignoredRows: ignoredRows
    )
  }

  private func value(at index: Int?, in row: [String]) -> String {
    guard let index, row.indices.contains(index) else { return "" }
    return row[index]
  }

  private func escape(_ value: String) -> String {
    guard
      value.contains(",") || value.contains("\"") || value.contains("\r") || value.contains("\n")
    else {
      return value
    }
    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }

  private func parseRows(_ text: String) -> [[String]] {
    let characters = Array(text)
    var rows = [[String]]()
    var row = [String]()
    var field = String()
    var quoted = false
    var index = 0

    while index < characters.count {
      let character = characters[index]
      if character == "\"" {
        if quoted, index + 1 < characters.count, characters[index + 1] == "\"" {
          field.append("\"")
          index += 1
        } else {
          quoted.toggle()
        }
      } else if character == "," && !quoted {
        row.append(field)
        field.removeAll(keepingCapacity: true)
      } else if (character == "\n" || character == "\r" || character == "\r\n") && !quoted {
        row.append(field)
        field.removeAll(keepingCapacity: true)
        if !row.isEmpty { rows.append(row) }
        row.removeAll(keepingCapacity: true)
        if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" {
          index += 1
        }
      } else {
        field.append(character)
      }
      index += 1
    }
    if !field.isEmpty || !row.isEmpty {
      row.append(field)
      rows.append(row)
    }
    return rows
  }
}
