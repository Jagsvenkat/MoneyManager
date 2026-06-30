# Money Manager

A cross-platform, offline-first, end-to-end encrypted personal finance tracking app built with Flutter.

Track expenses, income, loans, investments, and recurring transactions — all encrypted before touching disk. Sync to a private GitHub repository as an encrypted cloud backup.

## Features

- **Expense Tracking** — Log and categorize expenses with tags, amounts, dates, and custom metadata fields per category
- **Income Tracking** — Track salary, freelance, rental, and other income sources
- **Loan Management** — Record loans you've lent or borrowed with principal, interest rate, EMI, due dates, and repayment history
- **Investment Portfolio** — Track stocks, mutual funds, FD, gold, crypto, and more with buy price, current price, units, and gain/loss
- **Recurring Transactions** — Set up daily/weekly/monthly/custom recurring rules that auto-generate records
- **Accounts & Wallets** — Maintain multiple accounts (Cash, Bank, UPI, Credit Card, Savings), track balances, and transfer between them
- **Category-level Budgets** — Set monthly spending limits per expense category with real-time progress bars
- **Smart Insights** — Local-only analysis for spending spikes, top category growth, subscription detection, savings trends, and projected month-end spend
- **Dashboard** — Overview with balance, portfolio value, net liability, budget progress, charts, and recent activity
- **Charts & Reports** — Visual spending overview with period selectors (1M/3M/6M/1Y/3Y)
- **Export / Import** — Full data export to `.xlsx` and import from previously exported files
- **GitHub Sync** — End-to-end encrypted backup to a private GitHub repository

## Security Model

All data is encrypted **before** being written to disk or sent to GitHub.

| Layer | Algorithm | Purpose |
|-------|-----------|---------|
| Key Derivation | PBKDF2-HMAC-SHA512 (600K iterations) | Derives User Master Key (UMK) from username + password + salt |
| Envelope Encryption | XChaCha20-Poly1305 AEAD | Each record gets a unique 32-byte Data Encryption Key (DEK) |
| Key Wrapping | HKDF-SHA256 | Wrapping Key derived from UMK to encrypt each DEK |
| Session Storage | AES-GCM via `flutter_secure_storage` | Encrypted session key stored in platform keychain/keystore |
| Cloud Backup | Same envelope encryption | Sync file encrypted before upload to GitHub |

**No plaintext data ever touches disk or network.** The server (GitHub) only sees encrypted blobs.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                    UI Screens                    │
│  Dashboard │ Expenses │ More │ Reports │ Settings │
└──────────────────────┬──────────────────────────┘
                       │ Provider (State Management)
┌──────────────────────▼──────────────────────────┐
│              AuthService / AppProvider            │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│           LocalDatabaseService (Hive CE)          │
│  Encrypted CRUD for all record types              │
│  Typed models with fromJson/toJson/validate()     │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│         EnvelopeEncryption (XChaCha20-Poly1305)   │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│     Hive CE (IndexedDB / File System)            │
│     flutter_secure_storage (Keychain / Keystore)  │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│      GitHubSyncService (Dio → GitHub API)         │
└─────────────────────────────────────────────────┘
```

## Tech Stack

- **Framework:** Flutter 3.x (Dart 3.x)
- **State Management:** Provider
- **Routing:** GoRouter
- **Local Storage:** Hive CE (encrypted boxes)
- **Encryption:** `cryptography` package (PBKDF2, HKDF, XChaCha20-Poly1305)
- **Secure Storage:** `flutter_secure_storage`
- **Charts:** fl_chart
- **Export:** excel (`.xlsx`)
- **HTTP:** Dio (GitHub API)
- **Testing:** flutter_test + mocktail

## Setup

### Prerequisites

- Flutter SDK 3.27+
- Dart 3.6+
- A code editor (VS Code or Android Studio)
- (Optional) A GitHub account + Personal Access Token for sync

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/money_manager.git
cd money_manager

# Get dependencies
flutter pub get

# Generate Hive adapters (only needed if modifying models)
# dart run build_runner build

# Run in development
flutter run
```

### Platform-specific Setup

**Android:**
- Minimum SDK: 24 (API level 24)
- No additional configuration needed

**iOS:**
- Minimum deployment target: 15.0
- Add Keychain capability in Xcode for `flutter_secure_storage`

**Web:**
- Hive CE uses IndexedDB automatically
- For GitHub Pages deployment: set `webBaseHref` in `pubspec.yaml`

### Build Commands

```bash
# Web
flutter build web --release --base-href=/money_manager/

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

## GitHub Sync Setup

1. Create a **private** GitHub repository
2. Generate a Personal Access Token (PAT) with `Contents: Read and Write` permission
3. In the app, go to **Settings → GitHub Sync**
4. Enter your PAT, repo owner (username), and repo name
5. Tap **Save**
6. Use the cloud upload icon on the Dashboard to trigger a sync

**Important:** The PAT is stored in `flutter_secure_storage` and sent only to `api.github.com`. The sync file is encrypted end-to-end — GitHub only sees ciphertext.

## Export / Import

### Export
All data is exported to a single `.xlsx` file with these sheets:
- Expenses, Income, Loans, Investments, Recurring Rules, Accounts

On **mobile**, the file is shared via the system share sheet. On **web**, it downloads directly.

### Import
Import a previously exported `.xlsx` file:
- Records with existing IDs are **skipped** (safe re-import)
- New records are created with generated IDs if none provided
- Supports the same 6 sheets as export

## Development

### Project Structure

```
lib/
├── config/           # App routes, colors, extra field definitions
├── core/
│   ├── database/     # LocalDatabaseService, DatabaseHelpers
│   ├── security/     # EnvelopeEncryption, KDF, SecureStorage
│   └── services/     # GitHubSyncService, AuthService
├── features/
│   ├── accounts/     # Account management screen
│   ├── auth/         # Login, Register screens
│   ├── categories/   # Category management screen
│   ├── dashboard/    # Dashboard screen
│   ├── expenses/     # Expenses list screen
│   ├── recurring/    # Recurring rules screen
│   ├── reports/      # Reports screen
│   └── shared/       # Shared screens (More, Settings) & widgets
├── models/           # Typed data models with validation
└── providers/        # AppProvider, AuthProvider
```

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/model_test.dart

# Run with coverage
flutter test --coverage
```

### Coding Conventions

- This project uses Dart records and enhanced enums where appropriate
- State management uses Provider with `ChangeNotifier`
- All data models include `fromJson()`, `toJson()`, `validate()` methods
- Database CRUD operations go through `LocalDatabaseService`
- Screens access data via `AuthProvider.authService.database`
- UI follows Material 3 design with `ColorScheme` theming

## Known Limitations

- **Single-user only** — no multi-user or sharing support
- **INR currency only** — internationalization coming in future releases
- **No biometric lock for app start** — encryption is at the data layer, not app-level
- **Recurring rules** require manual triggering via `processDueRecurringRules()` (no background timer)
- **Month-end edge cases** — recurring rules on Jan 31 → Feb 28 may behave unexpectedly
- **Sync is manual** — no automatic background sync; triggered via Dashboard button
- **No push notifications** — no reminders for due bills or loan repayments
- **Test coverage** — covers models, security, sync merge; UI tests are minimal

## License

MIT License — see LICENSE file for details.
