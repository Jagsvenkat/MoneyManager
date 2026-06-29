# Money Manager — Architecture Guide

## 1. Overview

Money Manager is an **offline-first, end-to-end encrypted** personal finance tracking app built with **Flutter**. It stores all data locally in encrypted Hive boxes, with optional GitHub-based cloud backup. The app uses envelope encryption (XChaCha20-Poly1305 AEAD) with PBKDF2-HMAC-SHA512 key derivation, ensuring the server never sees plaintext data.

**Target users:** 5–10 internal users.  
**Distribution:** GitHub Pages (web), direct APK (Android), TestFlight (iOS).

---

## 2. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Framework | Flutter 3.x (Dart SDK ^3.12.0) | Cross-platform UI |
| State management | Provider + ChangeNotifier | Lightweight reactive state |
| Routing | GoRouter | Declarative navigation with auth guards |
| Local DB | Hive CE (Hive Community Edition) | Encrypted envelope storage (JSON strings) |
| Cryptography | `cryptography` package (XChaCha20-Poly1305, PBKDF2, HKDF) | AEAD encryption, key derivation |
| Secure storage | `flutter_secure_storage` (mobile) / `SharedPreferences` (web) | Salts, encrypted UMK, session tokens |
| Sync | Custom `GitHubSyncService` + Dio (HTTP) | Push/pull encrypted envelopes to GitHub repo |
| Charts | fl_chart | Dashboard pie chart + trend line |
| Export | excel + share_plus | XLSX export (web download / mobile share) |

**Key package versions (pubspec.yaml):** `hive_ce: ^2.19.3`, `cryptography: ^2.9.0`, `go_router: ^14.2.0`, `provider: ^6.1.2`, `dio: ^5.4.3`, `fl_chart: ^0.69.0`

---

## 3. Directory Structure

```
lib/
├── main.dart                          # App entry, MultiProvider + MaterialApp.router
├── config/
│   ├── app_colors.dart                # Material 3 color palette (dark theme)
│   └── app_routes.dart                # GoRouter config with auth redirect
├── providers/
│   ├── auth_provider.dart             # Auth state: login/register/logout/auto-login
│   └── app_provider.dart              # Current tab index for bottom nav
├── core/
│   ├── security/
│   │   ├── kdf.dart                   # PBKDF2-HMAC-SHA512 key derivation + HKDF wrapping
│   │   ├── envelope.dart              # XChaCha20-Poly1305 envelope encrypt/decrypt
│   │   └── secure_storage.dart        # Platform-aware secure storage (native/web)
│   ├── services/
│   │   ├── auth_service.dart          # Registration, login, session, password change
│   │   └── github_sync_service.dart   # GitHub API push/pull/full sync
│   └── database/
│       └── local_database.dart        # 8 Hive boxes, CRUD for all record types
├── features/
│   ├── auth/
│   │   ├── screens/login_screen.dart
│   │   ├── screens/register_screen.dart
│   │   └── widgets/password_strength_indicator.dart
│   ├── dashboard/screens/dashboard_screen.dart
│   ├── expenses/screens/expenses_screen.dart
│   ├── shared/screens/
│   │   ├── main_app_screen.dart       # Bottom nav with 4 tabs
│   │   ├── other_entries_screen.dart  # Combined Income/Loans/Investments tab
│   │   └── settings_screen.dart       # Full settings + export + sync config
│   └── categories/screens/categories_screen.dart
```

---

## 4. Security Model

### 4.1 Key Hierarchy

```
Password + Username + Salt (32 bytes)
         │
         ▼
  PBKDF2-HMAC-SHA512 (600,000 iterations)
         │
         ▼
   User Master Key (UMK) — 32 bytes
         │
    ┌────┴──────────────────────────┐
    │                               │
    ▼                               ▼
 HKDF-SHA256(context)        HKDF-SHA256(context)
    │                               │
    ▼                               ▼
 Wrapping Key (WK)            Backup Wrapping Key (BWK)
    │                               │
    ▼                               ▼
 Encrypts each record's      Encrypts UMK itself for
 Data Encryption Key (DEK)   password recovery (backup)
```

### 4.2 Envelope Encryption — Per-Record

Every financial record (expense, income, loan, investment) is encrypted as an `EncryptionEnvelope`:

```
┌──────────────────────────────────────────────────────────┐
│                   EncryptionEnvelope                      │
├──────────────────────────────────────────────────────────┤
│ recordId  │ UUID v4                                      │
│ version   │ "1.0"                                        │
│ deviceId  │ Persistent device UUID                       │
│ timestamp │ UTC creation/update time                     │
│ encDek    │ DEK encrypted with Wrapping Key + wrapping   │
│           │ nonce (concatenated, base64)                 │
│ nonce     │ 24-byte XChaCha20 nonce (base64)             │
│ ciphertext│ Payload encrypted with DEK (incl. MAC tag)   │
│ aad       │ Authenticated metadata: version, deviceId,   │
│           │ timestamp, recordId, type, userId (JSON)     │
│ syncStatus│ "pending" / "synced" / "conflict"            │
└──────────────────────────────────────────────────────────┘
```

**Encryption flow per record:**
1. Generate random 32-byte **DEK** (Data Encryption Key)
2. Generate random 24-byte **nonce** for XChaCha20-Poly1305
3. AEAD-encrypt payload with DEK + nonce + AAD
4. Generate random 24-byte **wrapping nonce**
5. AEAD-encrypt DEK with Wrapping Key + wrapping nonce + same AAD
6. Store `wrappingNonce || encryptedDEK` as `encDek`

**Decryption reverses this:** unwrap DEK, then decrypt payload.

### 4.3 Authentication Flow

**Registration:**
1. Generate 32-byte random salt
2. Derive UMK via PBKDF2(username + password, salt, 600K iterations)
3. Encrypt UMK with password-derived backup key → store in secure storage
4. Store KDF params (salt, algorithm, iterations) in secure storage
5. Initialize Hive DB with UMK as wrapping key
6. Save session (random key + encrypted UMK) for auto-login

**Login:**
1. Load KDF params for username from secure storage
2. Re-derive UMK from username + password + stored salt
3. Verify by decrypting stored backup UMK (password test)
4. Initialize Hive DB
5. Save new session

**Auto-login:**
1. Load stored session key + encrypted UMK from secure storage
2. Decrypt UMK using session key
3. Initialize Hive DB (no password re-entry needed)

### 4.4 Password Policy

- **Minimum 12 characters**
- Must contain: uppercase, lowercase, digit, special character
- Strength indicator shows real-time feedback
- Score 0–6 based on length + character variety

---

## 5. Data Flow

### 5.1 App Startup

```
main() ──► Hive.initFlutter()
     │
     ├─► AuthProvider.initialize()
     │       ├─► AuthService.initialize()
     │       │       ├─► SecureStorageService.initialize()
     │       │       │       ├─► NativeSecureStorage (mobile)
     │       │       │       └─► WebSecureStorage (web)
     │       │       └─► Load/create device ID
     │       │
     │       └─► AuthService.tryAutoLogin()
     │               ├─► Load session key + encrypted UMK
     │               ├─► Decrypt UMK
     │               └─► LocalDatabaseService.initialize(wrappingKey: UMK)
     │                       ├─► Open 8 Hive boxes
     │                       └─► Seed default categories (if empty)
     │
     └─► AppProvider (tracks tab index)
     │
     ▼
   GoRouter redirect:
     ├─► Authenticated → "/" (MainAppScreen)
     └─► Not authenticated → "/login"
```

### 5.2 Creating a Record (e.g., Expense)

```
User taps FAB (+) → Add Expense bottom sheet
     │
     ├─► User fills description, amount, date, category, tag
     │
     └─► On "Save" press:
             │
             ├─► LocalDatabaseService.createExpense(data)
             │       ├─► EnvelopeEncryption.encrypt(payload, wrappingKey)
             │       ├─► Store base64 JSON envelope in Hive `expenses` box
             │       └─► _addToSyncQueue('expense', id, 'create')
             │
             └─► UI shows success snackbar, list refreshes
```

### 5.3 Reading Records

```
Screen loads → Provider fires → AuthService.database.listExpenses()
     │
     ├─► Iterate all values in Hive `expenses` box
     ├─► For each: jsonDecode → EncryptionEnvelope.fromJson
     ├─► EnvelopeEncryption.decrypt(envelope, wrappingKey)
     ├─► Skip any decryption errors (data integrity)
     ├─► Skip 'conflict' sync status records
     └─► Return sorted (newest first) plaintext records
```

### 5.4 Edit/Delete

**Edit:** Read current record → merge updates → delete old → create new (same UUID).  
**Delete:** Remove from Hive box + add sync queue entry.  
Both operations append to the sync queue for later propagation.

---

## 6. Navigation & UI

### 6.1 Route Structure (GoRouter)

| Route | Screen | Auth Required |
|---|---|---|
| `/login` | LoginScreen | No |
| `/register` | RegisterScreen | No |
| `/` | MainAppScreen (4 tabs) | Yes |
| `/categories?type={type}` | CategoriesScreen | Yes |

**Auth redirect:** GoRouter middleware checks `AuthProvider.isAuthenticated` and redirects accordingly.

### 6.2 Bottom Navigation (MainAppScreen)

```
┌──────────┬───────────┬──────────┬──────────┐
│ Dashboard │ Expenses  │   More   │ Settings │
│  (home)   │ (receipt) │ (horiz)  │ (cog)    │
└──────────┴───────────┴──────────┴──────────┘
```

**Tab details:**

| Tab | Screen | Description |
|---|---|---|
| Dashboard | `DashboardScreen` | Overview: month selector, expense pie chart, income trend, totals |
| Expenses | `ExpensesScreen` | Searchable/filterable expense list, add/edit with category & tag |
| More | `OtherEntriesScreen` | Segmented control: Income / Loans / Investments, each with full CRUD |
| Settings | `SettingsScreen` | Account info, security info, category management (4 types), export, GitHub sync config, logout |

### 6.3 FAB Behavior

The FAB (+) on the main screen always opens the **Add Expense** bottom sheet (most frequent action). Income, Loan, and Investment entries are added from the **More tab** via the app bar + button.

### 6.4 Categories

Managed per type (expense/income/loan/investment) via Settings → Categories section. Each category has:
- Name, color (20-color palette), tags (free-text)
- 41 default categories seeded on first DB init across all 4 types
- Add, edit, delete, add/remove tags

---

## 7. Data Models (Encrypted)

All data is stored as encrypted JSON strings in Hive boxes. No Hive type adapters are used — the `EncryptionEnvelope` serialization handles all records.

### Record Schemas (plaintext payload)

**Expense:**
```json
{
  "id": "uuid-v4",
  "description": "Pizza",
  "amount": 499.0,
  "category": "Food & Dining",
  "tag": "Zomato/Swiggy",
  "dateTime": "2026-06-29T12:30:00.000Z"
}
```

**Income:**
```json
{
  "id": "uuid-v4",
  "amount": 50000.0,
  "source": "Salary",
  "frequency": "monthly",
  "dateTime": "2026-06-01T00:00:00.000Z"
}
```

**Loan:**
```json
{
  "id": "uuid-v4",
  "personName": "Rahul",
  "amount": 10000.0,
  "loanType": "To Receive",
  "dateTime": "2026-06-15T00:00:00.000Z"
}
```

**Investment:**
```json
{
  "id": "uuid-v4",
  "name": "HDFC Bank",
  "type": "equity",
  "units": 10.0,
  "pricePerUnit": 1850.0,
  "dateTime": "2026-06-20T00:00:00.000Z"
}
```

**Category:**
```json
{
  "id": "expense_Food_&_Dining",
  "name": "Food & Dining",
  "type": "expense",
  "color": 4293849470,
  "tags": ["Meals", "Snacks", "Groceries", "Zomato/Swiggy"]
}
```

### Hive Boxes

| Box Name | Value Type | Purpose |
|---|---|---|
| `expenses` | `String` (JSON envelope) | Expense records |
| `income` | `String` (JSON envelope) | Income records |
| `loans` | `String` (JSON envelope) | Loan records |
| `investments` | `String` (JSON envelope) | Investment records |
| `categories` | `String` (JSON envelope) | Category definitions |
| `balance` | `String` (JSON envelope) | Balance snapshots |
| `sync_queue` | `Map` (plain) | Pending sync operations |
| `conflicts` | `String` (JSON envelope) | Conflict records |

**Important:** All user data boxes store encrypted envelopes. Only `sync_queue` and `conflicts` contain non-encrypted metadata (sync operation type, record ID, status).

---

## 8. GitHub Sync

### 8.1 Architecture

Sync uses **GitHub Contents API** to store encrypted envelopes as individual files in a dedicated repo:

```
https://api.github.com/repos/{owner}/{repo}/contents/{userId}/
├── expenses/{recordId}.json
├── income/{recordId}.json
├── loans/{recordId}.json
├── investments/{recordId}.json
└── categories/{recordId}.json
```

### 8.2 Sync Operations

**Push (upload local changes):**
1. Read `sync_queue` for pending items
2. For each pending operation (create/update/delete):
   - Fetch current file SHA (for idempotent update)
   - PUT file to GitHub Contents API with SHA
   - Mark queue item as `synced`
   - Handle 409 (conflict) by re-fetching SHA

**Pull (download remote changes):**
1. GET GitHub Contents API for directory listing
2. For each remote file not present locally (or newer):
   - Download file content
   - Decrypt envelope
   - Store locally
   - Mark as synced

**Full sync:** Push first, then pull.

### 8.3 Auth

- Uses GitHub Personal Access Token (PAT) with `Contents: Read and Write` permission
- Auth header: `Authorization: Bearer {token}`
- Token is encrypted with UMK and stored in `flutter_secure_storage`
- Configurable via Settings → Backup → GitHub Sync dialog

### 8.4 Dashboard Sync Button

The Dashboard app bar has a cloud-upload icon that triggers `pushChanges()`. Shows a loading indicator during sync, displays success/failure message. Warns if GitHub sync is not configured.

---

## 9. State Management

Two `ChangeNotifier` providers, scoped via `MultiProvider` at the app root:

**AuthProvider** (`providers/auth_provider.dart`):
- `isAuthenticated`, `currentUserId`, `isLoading`, `error`
- Methods: `initialize()`, `login()`, `register()`, `logout()`, `deleteAccount()`
- Wraps `AuthService` for all auth operations
- GoRouter listens to this for redirect decisions

**AppProvider** (`providers/app_provider.dart`):
- `currentTabIndex` — which bottom nav tab is active
- `setTabIndex(int)` — switch tabs

Individual screens use `StatefulWidget` with local state for their data. Data is loaded from `AuthProvider.authService.database` on `didChangeDependencies()` and refreshed after mutations via `setState()`.

---

## 10. Export

**Web:** `excel.save()` triggers browser download of `.xlsx` file.  
**Mobile:** Write to temp directory → `Share.shareXFiles()` shares via system share sheet.

Export includes 4 sheets: Expenses, Income, Loans, Investments — each with relevant columns and date-formatted rows.

---

## 11. Testing

| File | Tests | Type |
|---|---|---|
| `test/security_test.dart` | 17 tests: KDF consistency, envelope roundtrip, decryption failure, password validation, secure random | Unit + Integration |
| `test/sync_tests.dart` | Sync service with mocked database | Unit |
| `test/widget_test.dart` | Basic app smoke test | Widget |

**Run:** `flutter test`

---

## 12. Deployment

### 12.1 Web (GitHub Pages)

```yaml
# .github/workflows/deploy.yml — triggers on push to main
1. Checkout repo
2. Setup Flutter
3. flutter build web --base-href /MoneyManager/
4. Upload Pages Artifact
5. Deploy to Pages
```

Live at: `https://jagsvenkat.github.io/MoneyManager/`

### 12.2 Android (APK)

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/SJsaver-release.apk
```

### 12.3 iOS (TestFlight)

```bash
flutter build ios --release
# Archive in Xcode → Upload to App Store Connect → TestFlight
```

---

## 13. Secure Storage Keys

| Key Pattern | Storage | Purpose |
|---|---|---|
| `kdf_params_{userId}` | Secure storage | Salt + algorithm + iteration params |
| `umk_{userId}` | Secure storage | UMK encrypted with password-derived key (backup) |
| `session_key` | Secure storage | Random 32-byte key for session |
| `session_umk` | Secure storage | UMK encrypted with session key |
| `last_user_id` | Secure storage | Last logged-in username |
| `device_id` | Secure storage | Persistent device UUID |
| `sync_settings` | Secure storage | GitHub owner + repo name |
| `github_pat_{userId}` | Secure storage | GitHub PAT encrypted with UMK |

---

## 14. Development Guide

### Getting Started

```bash
git clone <repo>
cd money_manager
flutter pub get
flutter run -d chrome    # Web
flutter run -d <device>  # Mobile
```

### Code Style

- No comments in code (except for doc comments on public APIs)
- Dart with Flutter conventions
- StatefulWidget + local state for screens
- Provider for global state only
- Use `AppColors` constants everywhere (no hardcoded colors)

### Adding a New Feature

1. Add DB method in `LocalDatabaseService`
2. Create/update screen in `features/{name}/screens/`
3. Wire into navigation (tabs in `MainAppScreen` or route in `AppRoutes`)
4. Add mock method to `test/sync_tests.dart` if sync-related

### Building for Production

```bash
flutter build web --base-href /MoneyManager/ --release
flutter build apk --release
flutter build ios --release --no-codesign
```

---

## 15. Key Design Decisions

| Decision | Rationale |
|---|---|
| **No Hive type adapters** | Data is stored as encrypted JSON strings; adapters add complexity with no benefit |
| **PBKDF2 over Argon2id** | Cross-platform Dart `cryptography` package has stable PBKDF2; Argon2id support planned |
| **Per-record DEK** | Each record has its own Data Encryption Key, wrapped by the UMK-derived WK. Re-keying only requires re-wrapping DEKs, not re-encrypting payloads |
| **AAD includes recordId + userId** | Prevents record swapping attacks (authenticated data is bound to the record) |
| **Sync queue** | Append-only log of mutations ensures eventual consistency even if sync fails mid-operation |
| **GitHub as backend** | Zero server cost, familiar API, no additional infra. PATs scoped to single repo |
| **Bottom sheet dialogs** | Modal bottom sheets for add/edit — more natural on mobile, works well on web |
| **No light theme** | Dark-only simplifies the theme surface; Material 3 dark theme is visually refined |
| **Expense FAB + More tab** | Expense entry is the most frequent action. Other entry types are grouped under a single tab |

---

## 16. File Inventory

### Source Files (lib/)

| File | Lines | Purpose |
|---|---|---|
| `main.dart` | 130 | App entry point, theme, providers |
| `config/app_colors.dart` | 111 | Material 3 dark palette |
| `config/app_routes.dart` | 54 | GoRouter with auth guard |
| `providers/auth_provider.dart` | 111 | Auth state management |
| `providers/app_provider.dart` | 23 | Tab index state |
| `core/security/kdf.dart` | 99 | PBKDF2 + HKDF key derivation |
| `core/security/envelope.dart` | 239 | XChaCha20-Poly1305 envelope |
| `core/security/secure_storage.dart` | 248 | Platform-aware secure storage |
| `core/services/auth_service.dart` | 369 | Registration, login, session |
| `core/services/github_sync_service.dart` | 271 | GitHub API sync |
| `core/database/local_database.dart` | 600 | 8 Hive boxes, CRUD, sync queue |
| `features/auth/screens/login_screen.dart` | 124 | Login UI |
| `features/auth/screens/register_screen.dart` | 162 | Registration UI |
| `features/auth/widgets/password_strength_indicator.dart` | 63 | Password strength bar |
| `features/dashboard/screens/dashboard_screen.dart` | 366 | Dashboard with charts + sync |
| `features/expenses/screens/expenses_screen.dart` | 630 | Expense CRUD with search/filter |
| `features/shared/screens/main_app_screen.dart` | 237 | Bottom nav + FAB |
| `features/shared/screens/other_entries_screen.dart` | 1054 | Income/Loans/Investments combined |
| `features/shared/screens/settings_screen.dart` | 455 | Settings, export, sync config |
| `features/categories/screens/categories_screen.dart` | 290 | Category management |

### Test Files

| File | Tests |
|---|---|
| `test/security_test.dart` | 17 (KDF, envelope, password, random) |
| `test/sync_tests.dart` | Sync service unit tests |
| `test/widget_test.dart` | App smoke test |

### Config Files

| File | Purpose |
|---|---|
| `pubspec.yaml` | Dependencies, launcher icons |
| `analysis_options.yaml` | Dart lint rules |
| `.gitignore` | Ignored files (`.dart_tool/`, `build/`, `.env`, etc.) |
| `.metadata` | Flutter project metadata |
| `devtools_options.yaml` | Flutter DevTools extension config |
| `.github/workflows/deploy.yml` | GitHub Pages deploy |
