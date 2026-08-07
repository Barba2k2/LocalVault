# `.localvault` backup format

Version 1 is a JSON envelope. Binary fields use the standard `JSONEncoder` base64 representation.

```json
{
  "formatVersion": 1,
  "kdf": "PBKDF2-HMAC-SHA256",
  "iterations": 600000,
  "salt": "<16 random bytes, base64>",
  "nonce": "<12 random bytes, base64>",
  "ciphertext": "<AES-GCM ciphertext and 16-byte authentication tag, base64>"
}
```

The backup password is never stored. The encryption key is derived from the password using PBKDF2-HMAC-SHA256 with 600,000 iterations and the 16-byte random salt. The resulting key encrypts the serialized credential payload with AES-256-GCM. The 12-byte nonce is unique per backup and the authentication tag is included at the end of `ciphertext`.

Readers must reject unknown versions, KDF parameters, wrong salt/nonce sizes, ciphertext shorter than the authentication tag, and ciphertext larger than 64 MiB before attempting decryption. Export and restore are separate tasks; this document defines the stable container contract they must use.
