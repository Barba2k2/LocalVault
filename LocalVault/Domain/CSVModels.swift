import Foundation

struct CSVImportIssue: Equatable, Sendable {
  let row: Int
  let reason: String
}

struct CSVImportResult: Equatable, Sendable {
  let headers: [String]
  let credentials: [Credential]
  let invalidRows: [CSVImportIssue]
  let ignoredRows: [Int]
}

protocol CSVService: Sendable {
  func export(_ credentials: [Credential]) throws -> Data
  func preview(_ data: Data) throws -> CSVImportResult
}
