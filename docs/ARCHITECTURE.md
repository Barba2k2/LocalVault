# LocalVault architecture

## Boundaries

`Domain/` owns vault concepts and contracts. It contains no SwiftUI, Keychain,
LocalAuthentication, file-system, or CryptoKit implementation.

`Infrastructure/` will implement the contracts using platform APIs:

- encrypted credential persistence;
- CryptoKit authenticated encryption;
- Keychain key lifecycle;
- LocalAuthentication;
- versioned `.localvault` backup format.

`Features/` will compose user flows such as onboarding, lock screen, credential
list/detail, settings, and backup. Views must depend on domain contracts, not
concrete storage or cryptography.

`App/` owns composition, scene lifecycle, background locking, and privacy
redaction. Sensitive values must never enter `UserDefaults`, logs, analytics,
crash reports, or view state longer than necessary.

## Credential model

`Credential` contains title, username, password, optional URL, notes, optional
category, and creation/update timestamps. It is `Codable` for serialization by
the persistence and backup adapters, but the domain does not decide how data is
stored or encrypted.

## Dependency direction

```text
App -> Features -> Domain <- Infrastructure
```

Infrastructure conforms to domain protocols. Domain remains platform-neutral
enough to compile for iOS and macOS targets later.

## Security decisions

- The vault key lives in Keychain, never beside the database.
- Sensitive persistence uses authenticated encryption.
- Backup password and vault key are separate secrets.
- Authentication failure fails closed.
- Backup restoration validates completely before replacing local data.
