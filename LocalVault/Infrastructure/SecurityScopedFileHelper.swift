import Foundation

/// Reads files picked through `fileImporter`, which hand back security-scoped
/// URLs that must be claimed before the bytes are readable.
enum SecurityScopedFileHelper {
  static func read(contentsOf url: URL) throws -> Data {
    // Returns false for URLs that are already reachable (in-sandbox paths and
    // some simulator URLs), so a false result is not an error — it only means
    // there is no claim to release afterwards.
    let didStartAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didStartAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    return try Data(contentsOf: url)
  }
}
