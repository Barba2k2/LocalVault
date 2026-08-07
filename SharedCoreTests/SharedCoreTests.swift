import Testing
@testable import SharedCore

@Test func sharedCoreExposesPortableBackupAndPasswordGeneration() throws {
  let credential = Credential(title: "Example", password: "secret")
  let backup = try EncryptedBackupService().makeBackup(
    from: [credential],
    password: "correct horse"
  )

  #expect(try EncryptedBackupService().restoreCredentials(from: backup, password: "correct horse") == [credential])
  #expect(try PasswordGenerator().generate(
    length: 16,
    includeUppercase: true,
    includeLowercase: true,
    includeNumbers: true,
    includeSymbols: true
  ).count == 16)
}
