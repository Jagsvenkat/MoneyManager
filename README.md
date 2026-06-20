# Money Manager - Offline-First Encrypted Financial App

A high-security, offline-first Flutter app for personal financial management supporting iOS, Android, and Web. All data is encrypted end-to-end at rest and in transit. Designed for small teams (up to 3 users) with strong cryptography and GitHub-based sync.

## Features

- **End-to-End Encryption**: Uses PBKDF2-HMAC-SHA512 for key derivation and XChaCha20-Poly1305 for AEAD encryption
- **Offline-First**: Full functionality without internet; sync when connected
- **Cross-Platform**: iOS, Android, and Web with responsive UI
- **No Paid Services**: Uses only free tools and GitHub free tier
- **Secure Key Management**: User Master Key (UMK) derived from password, secure storage on device/platform
- **Envelope Encryption**: Each record encrypted with random DEK, wrapped with user's wrapping key
- **GitHub Sync**: Private repo sync with conflict resolution and encrypted backups

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run app (choose platform)
flutter run -d "iPhone 14"      # iOS
flutter run -d emulator-id       # Android
flutter run -d chrome            # Web
```

## Security

- **PBKDF2-HMAC-SHA512**: Key derivation with 200,000 iterations
- **XChaCha20-Poly1305**: AEAD encryption for each record
- **Envelope Encryption**: DEK wrapped with user's UMK
- **Secure Storage**: Flutter_secure_storage (iOS Keychain, Android Keystore)
- **GitHub Sync**: Encrypted payload only; never plaintext in repo

See full README for complete setup, user guide, and architecture details.

**For comprehensive documentation, see the full README sections below.**

## Setup & Installation

See "Installation & Setup" section below for detailed instructions.

## Documentation

Full documentation available in `ARCHITECTURE.md` and `SECURITY.md`.

## Testing

```bash
flutter test
```

## License

MIT License
