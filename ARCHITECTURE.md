Architecture & Design Documentation
Overview
Money Manager is an offline-first, end-to-end encrypted financial management app built with Flutter. It follows a layered architecture with strong separation of concerns between security, data, and presentation layers.

Core Principles
Security First: Cryptography is embedded at every layer
Offline First: App fully functional without internet
User Privacy: No server backend, data only in user's repo
Simplicity: Minimal dependencies, clear code for security review
Cross-Platform: Single codebase for iOS, Android, Web
Architecture Layers
┌─────────────────────────────────────────┐
│         UI/Presentation Layer           │
│  (Screens, Forms, Dialogs, Charts)      │
├─────────────────────────────────────────┤
│         Business Logic Layer            │
│  (Services: Auth, Sync, Export)         │
├─────────────────────────────────────────┤
│         Data Access Layer               │
│  (Local Database with Encryption)       │
├─────────────────────────────────────────┤
│         Security Layer                  │
│  (KDF, Envelope Encryption, Storage)    │
└─────────────────────────────────────────┘
Layer Descriptions
1. Security Layer (lib/core/security/)
Purpose: Cryptographic operations and key management

Components:

kdf.dart - Key Derivation Function

PBKDF2-HMAC-SHA512 with 200,000+ iterations
Derives User Master Key (UMK) from username + password + salt
Derives wrapping keys via HKDF-SHA256
envelope.dart - Envelope Encryption

XChaCha20-Poly1305 AEAD encryption
Per-record Data Encryption Keys (DEK)
DEK wrapping for key rotation
Metadata integrity via AAD
Tamper detection through MAC
secure_storage.dart - Secure Storage

Platform-specific implementations (Keychain/Keystore)
Web fallback to encrypted IndexedDB
Stores salts, KDF params, encrypted UMK, GitHub PAT
Key Classes:

KdfParams           // Configuration for key derivation
KeyDerivationFunction // PBKDF2 implementation
EncryptionEnvelope  // Encrypted record container
EnvelopeEncryption  // Encryption/decryption operations
SecureStorageService // Platform-specific storage
Threat Model:

✅ Protects against: Passive data theft, device theft, repo exposure
❌ Not protected against: Keyloggers, physical coercion, OS compromise
2. Data Access Layer (lib/core/database/)
Purpose: Persistent encrypted storage with CRUD operations

Components:

local_database.dart - LocalDatabaseService
Hive-CE integration for encrypted local DB
Envelope encryption/decryption for all records
Sync queue for offline changes
Conflict storage for merge resolution
Storage Structure:

Hive Boxes:
├── expenses          (encrypted JSON)
├── income            (encrypted JSON)
├── balance           (encrypted JSON)
├── loans             (encrypted JSON)
├── investments       (encrypted JSON)
├── categories        (encrypted JSON)
├── sync_queue        (pending operations)
└── conflicts         (conflicting versions)
Key Methods:

initialize()                    // Open boxes, set encryption key
createExpense/Income/Loan/etc  // Add encrypted record
readExpense/Income/Loan/etc    // Decrypt and return record
listExpenses/Income/etc        // Query with filters
updateExpense/Income/etc       // Decrypt, update, re-encrypt
deleteExpense/Income/etc       // Remove record
Design Decisions:

Hive-CE: Lightweight, Dart-native, supports custom encryption
Per-Record Encryption: Allows encryption/decryption in isolation
JSON Envelopes: Platform-independent, easy to inspect/debug
Sync Queue: Ensures no data loss during offline→online transition
3. Business Logic Layer (lib/core/services/)
Purpose: High-level operations and integrations

Components:

auth_service.dart - AuthService

User registration with password validation
Login with KDF verification
Password change with key re-wrapping
Session management
UMK lifecycle (derive → encrypt → store → decrypt)
github_sync_service.dart - GitHubSyncService

Push local changes to GitHub
Pull remote changes and merge
Conflict detection (timestamp-based, last-write-wins)
Repository verification
Key Flows:

Registration Flow:

User Input
    ↓
Validate Password Strength
    ↓
Generate Random Salt (32 bytes)
    ↓
Derive UMK (PBKDF2)
    ↓
Encrypt UMK with Password-Derived Key
    ↓
Store KDF Params + Encrypted UMK in Secure Storage
    ↓
Initialize Local Database
    ↓
Return Encrypted Backup to User
Login Flow:

User Input
    ↓
Load KDF Params from Secure Storage
    ↓
Derive UMK (using stored params)
    ↓
Verify by Decrypting Backup UMK
    ↓
Initialize Local Database
    ↓
Create Session
Sync Push Flow:

Collect All Records (Expenses, Income, etc.)
    ↓
Create Sync Envelope (encrypted)
    ↓
Upload to GitHub (base64 encoded)
    ↓
Mark Records as 'synced'
    ↓
Update Sync Metadata
Sync Pull Flow:

Download Encrypted Backup from GitHub
    ↓
Decrypt Envelope
    ↓
For Each Record:
   - Check if Exists Locally
   - Compare Timestamps
   - Merge (last-write-wins)
   - Preserve Conflicts
4. Presentation Layer (lib/features/)
Purpose: User interface and user interactions

Feature Modules:

auth/ - Authentication UI

Login screen
Registration screen
Password strength indicator
Biometric unlock (optional)
dashboard/ - Dashboard and Overview

Current balance display
Charts (expense by category, income vs expense, etc.)
Quick stats (highest expense, average daily spend, etc.)
Month-to-date summary
expenses/ - Expense Management

Expense form (date, amount, category, merchant, etc.)
Expenses table with advanced filters
Sorting (date, amount, category, merchant)
Pagination or infinite scroll
Bulk actions (delete, assign category, mark reconciled)
CSV/XLSX export
income/ - Income Management

Income form with frequency selector
Income list with summary
Recurring income helpers
loans/ - Loan Management

Loan creation form
Loan details with amortization schedule
Repayment tracking
Automatic outstanding amount calculation
investments/ - Investment Tracking

Investment form
Portfolio overview
P&L calculation
Current value tracking
categories/ - Category Management

Custom category creation
Color and icon picker
Subcategory management
Bulk category assignment
reports/ - Reporting

Date range picker
Record type selection (Expenses, Income, Loans, Investments)
Excel workbook generation
Summary, Transactions, Income, Loans, Investments sheets
sync/ - Sync Management

GitHub PAT configuration
Manual sync button
Sync history
Conflict resolution UI
Sync status indicator
settings/ - Settings and Preferences

User profile
Security (password change, biometric, logout)
GitHub configuration
Data export/import
Device info
Data Flow Diagrams
Create Expense (Offline)
UI (Expense Form)
    ↓
ExpenseController.createExpense()
    ↓
AuthService.userMasterKey → UMK
    ↓
LocalDatabaseService.createExpense()
    ↓
EnvelopeEncryption.encrypt()
    - Generate random DEK (32 bytes)
    - Generate nonce (24 bytes)
    - Encrypt payload with DEK
    - Encrypt DEK with wrapping key
    - Create EncryptionEnvelope
    ↓
Hive Box ('expenses').put(id, envelopeJson)
    ↓
SyncQueue.add('expense', id, 'create')
    ↓
UI Updates (Show in list)
Sync to GitHub
SyncButton Tapped
    ↓
GitHubSyncService.fullSync()
    ↓
PUSH:
  - Collect all local records
  - Create sync envelope (all records)
  - Encrypt with UMK
  - Upload to GitHub (users/{userId}.json.enc)
  - Mark all as 'synced'
    ↓
PULL:
  - Download users/{userId}.json.enc from GitHub
  - Decrypt with UMK
  - For each record:
    * Compare timestamps
    * Merge (last-write-wins)
    * Preserve conflicts
  - Update local DB
    ↓
UI Updates (Show sync status)
Security Implementation Details
Key Derivation
Threat: Brute-force password attacks

Mitigation: PBKDF2-HMAC-SHA512

200,000 iterations minimum
Per-user random salt (32 bytes)
CPU-intensive key stretching
UMK = PBKDF2(
  password: username + password,
  salt: randomSalt,
  iterations: 200000,
  length: 32
)
Envelope Encryption
Threat: Plaintext data exposure, tampering

Mitigation: XChaCha20-Poly1305 AEAD

Random DEK per record
24-byte nonce (no collision risk)
Authenticated encryption (MAC)
Versioned AAD for upgrades
Envelope:
├── recordId
├── version
├── deviceId
├── timestamp
├── encDek (wrapped with UMK-derived key)
├── nonce
├── ciphertext (XChaCha20)
├── aad (Additional Authenticated Data)
└── syncStatus
Key Wrapping
Threat: DEK compromise

Mitigation: Envelope encryption pattern

Each DEK encrypted with wrapping key
Wrapping key derived from UMK via HKDF-SHA256
DEK never stored plaintext
WrappingKey = HKDF-SHA256(UMK, context='wrap')
EncryptedDEK = XChaCha20-Poly1305(DEK, WrappingKey)
Secure Storage
Mobile: flutter_secure_storage

iOS: Keychain (encryption via OS)
Android: Keystore (encryption via TEE if available)
Web: IndexedDB

Encrypted blob with password-derived key
Recovery requires password
Stored:

Salt (plaintext, per user)
KDF params (plaintext, per user)
Encrypted UMK (encrypted with password)
GitHub PAT (encrypted with UMK)
Conflict Resolution
Last-Write-Wins (LWW) Strategy

When two devices edit the same record:

Pull changes from GitHub
Compare updatedAt timestamps
Keep version with later timestamp
If timestamps equal: Mark as conflict
Store both versions encrypted
User resolves manually in UI
Example:

Device A (Timestamp: 2024-01-15 10:00:00):
  { expense: { id: "exp-1", amount: 100 } }

Device B (Timestamp: 2024-01-15 09:59:00):
  { expense: { id: "exp-1", amount: 99 } }

Result: Device A's version wins (later timestamp)
Performance Considerations
Encryption Overhead
Per-Record: ~50-100ms for encrypt/decrypt (1KB payload)
Batch Operations: ~500ms for 1000 records
Network: Negligible compared to API calls
Database Performance
Hive-CE: 10,000+ records queries in <1 second
Filtering: Index by category/date planned for >50k records
Sync: Incremental updates (delta sync) planned for Milestone 6
Optimization Strategies
Lazy Decryption: Only decrypt on view (not on list)
Caching: Keep recent records in memory (encrypted cache)
Batch Operations: Sync in batches of 100 records
Pagination: Show 20 records per page, load more on scroll
Testing Strategy
Unit Tests (test/security_tests.dart)
KDF consistency and salt handling
Encryption/decryption roundtrips
Tamper detection (corrupted ciphertext)
Password validation
Widget Tests (test/widget_tests.dart)
Login/signup forms
Expense form validation
Dashboard rendering
List filtering
Integration Tests (test/integration_tests.dart)
Full login → add → sync flow
Offline edits → online sync merge
Conflict resolution
Export/import cycle
Security Tests (test/security_tests.dart)
Tamper detection (modified AAD)
Wrong key decryption failure
Password strength validation
Rate limiting on auth attempts
Deployment Checklist
[ ] Update version in pubspec.yaml
[ ] Run all tests: flutter test
[ ] Generate coverage: flutter test --coverage
[ ] Lint: flutter analyze
[ ] Build all platforms: web, android, ios
[ ] Test on real devices (if possible)
[ ] Review SECURITY.md for latest best practices
[ ] Update README with new features
[ ] Create git tag: git tag v1.0.0
Future Enhancements
Milestone 6 (Post-Launch)
Delta Sync: Only sync changed records
Selective Sync: Choose which data to sync
Backup Versioning: Multiple GitHub backup versions
Data Sharding: Split user data across multiple files
Compression: GZIP before encryption for large syncs
Rate Limiting: Prevent sync spam (detect compromised device)
Milestone 7 (Long-term)
Server-Side Backup (optional, paid): S3-compatible storage
Collaborative Features: Shared expenses with spouse/business partner
Mobile Biometric: Face ID / Fingerprint unlock
Background Sync: Auto-sync on schedule
Data Analytics: Privacy-preserving local ML (trends, forecasts)
API Export: Export to other apps (YNAB, Mint, etc.)
References
Cryptography Package
OWASP Mobile Security
NaCl / Libsodium
PBKDF2 Specification
XChaCha20-Poly1305
Flutter Security Best Practices
Architecture Version: 1.0
Last Updated: 2024
Status: Complete for Milestone 1-3