import Foundation

struct Credential: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  var title: String
  var username: String
  var password: String
  var url: URL?
  var notes: String
  var category: String?
  let createdAt: Date
  var updatedAt: Date

  init(
    id: UUID = UUID(),
    title: String,
    username: String = "",
    password: String = "",
    url: URL? = nil,
    notes: String = "",
    category: String? = nil,
    createdAt: Date = Date(),
    updatedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.username = username
    self.password = password
    self.url = url
    self.notes = notes
    self.category = category
    self.createdAt = createdAt
    self.updatedAt = updatedAt ?? createdAt
  }
}
