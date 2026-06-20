# Git Commit Guide - Suggested Commit History

This guide shows the recommended commit structure for the Money Manager project, following best practices for security code review and change tracking.

## Milestone 1 Commits (Already Implemented)

### Commit 1: Project Scaffold & Dependencies
```
commit: scaffold: Initialize Flutter project with security dependencies

- Setup pubspec.yaml with cryptography packages
  * cryptography: ^2.10.0 (PBKDF2, HKDF, AES)
  * flutter_sodium: ^0.2.0 (XChaCha20-Poly1305)
  * crypto: ^3.0.7 (SHA-512 HMAC)
  
- Add state management: provider ^6.4.1
- Add local storage: hive_ce ^2.19.3, flutter_secure_storage ^9.2.2
- Add networking: dio ^5.4.3+1
- Add visualization: fl_chart ^0.69.0, excel ^2.0.2
- Add utilities: uuid, timezone, local_auth

- Create project structure:
  lib/core/security/
  lib/core/services/
  lib/core/database/
  lib/core/models/
  lib/features/

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 2: Core Cryptography - KDF
```
commit: crypto: Implement PBKDF2-HMAC-SHA512 key derivation

- Add KdfParams configuration class
  * Algorithm selection (pbkdf2, future: argon2id)
  * Iterations: 200,000 minimum
  * Output length: 32 bytes
  * Memory cost and parallelism params for Argon2id

- Implement KeyDerivationFunction
  * deriveUserMasterKey(username, password, salt)
  * deriveWrappingKey(umk, context)
  * PBKDF2 using cryptography package
  * Secure randomness via dart:math Random.secure

- Add password validation via PasswordValidator
  * Minimum 12 characters
  * Requires: uppercase, lowercase, numbers, special chars
  * Strength scoring and feedback messages

Security Notes:
  - 200k iterations provides ~1 second derivation time
  - Per-user 32-byte salt prevents rainbow tables
  - HKDF-SHA256 derives wrapping key to avoid DEK exposure
  - No hardcoded parameters

Tests Added:
  - KDF consistency with same inputs
  - Different outputs with different salts
  - Wrapping key derivation
  - Password strength validation

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 3: Envelope Encryption - AEAD
```
commit: crypto: Implement XChaCha20-Poly1305 envelope encryption

- Add EncryptionEnvelope data structure
  * recordId: Unique identifier
  * version: "1.0" for migrations
  * deviceId: Source device
  * timestamp: Creation/update time
  * encDek: Base64-encoded encrypted DEK
  * nonce: Base64-encoded unique nonce
  * ciphertext: Base64-encoded encrypted payload
  * aad: Additional Authenticated Data (plaintext JSON)
  * syncStatus: pending/synced/conflict
  * conflictMarker: Timestamp for conflict tracking

- Implement EnvelopeEncryption with XChaCha20-Poly1305
  * encrypt(): Generate DEK, nonce; encrypt payload and DEK
  * decrypt(): Decrypt DEK, then payload; verify MAC
  * Nonce: 24 bytes (XChaCha20 requirement)
  * AEAD: Includes version, deviceId, timestamp, recordId in AAD
  * Secure random generation for DEKs and nonces

- Add DecryptionException for tamper detection
  * Thrown when MAC verification fails
  * Indicates corrupted ciphertext or wrong key

Security Notes:
  - One random DEK per record (key material isolation)
  - 24-byte nonce prevents collision (birthday paradox)
  - AAD prevents tampering with metadata
  - XChaCha20: 256-bit key, 192-bit nonce
  - Poly1305: 128-bit authentication tag

Tests Added:
  - Encryption/decryption roundtrip
  - Tamper detection (modified ciphertext fails)
  - Tamper detection (modified AAD fails)
  - Wrong key decryption fails
  - Envelope JSON serialization

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 4: Secure Storage
```
commit: storage: Add platform-specific secure key storage

- Implement SecureStorageProvider interface
  * Platform abstraction for storage operations
  * save(key, value), read(key), delete(key), clear()

- Add NativeSecureStorage (iOS/Android)
  * iOS Keychain (via flutter_secure_storage)
  * Android Keystore (via flutter_secure_storage)
  * RSA/ECB/OAEPwithSHA-256 key cipher
  * AES/GCM/NoPadding storage cipher
  * resetOnError: false (preserve data on error)

- Add WebSecureStorage (fallback)
  * In-memory storage for development
  * Production: IndexedDB with client-side encryption

- Implement SecureStorageService
  * saveKdfParams: Store salt, algorithm, iterations
  * loadKdfParams: Retrieve KDF configuration
  * saveEncryptedUmk: Store password-protected backup
  * loadEncryptedUmk: Retrieve backup
  * saveGitHubPat: Store encrypted GitHub token
  * loadGitHubPat: Retrieve GitHub token
  * saveSyncMetadata: Track sync state
  * clearUserStorage: Logout cleanup

Security Notes:
  - Salts stored plaintext (acceptable, used for KDF)
  - UMK never stored plaintext
  - GitHub PAT encrypted with UMK
  - Platform-native encryption for iOS/Android
  - Web requires password for access (future: IndexedDB)

Tests Added:
  - Secure storage abstraction
  - Mock storage for unit tests

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 5: Authentication Service
```
commit: auth: Implement user registration, login, password change

- Add AuthService for user lifecycle
  * initialize(): Load/create device ID, secure storage
  * register(): Create account, derive UMK, save backup
  * login(): Verify password, initialize session
  * logout(): Cleanup
  * changePassword(): Re-wrap UMK with new password

- Registration Flow
  * Validate password strength (12+ chars, complex)
  * Generate random 32-byte salt
  * Derive UMK via PBKDF2(username+password, salt)
  * Encrypt UMK with password-derived backup key
  * Store KDF params + encrypted UMK in secure storage
  * Return encrypted backup to user (for safekeeping)

- Login Flow
  * Load KDF params from secure storage
  * Derive UMK using stored params
  * Verify by decrypting stored backup UMK
  * Throw "Invalid password" if mismatch
  * Initialize LocalDatabaseService with UMK

- Password Change
  * Verify current password
  * Derive new UMK (same salt, new password)
  * Re-encrypt with new password
  * Update secure storage
  * All data remains encrypted, just key changes

- Expose Public API
  * currentUserId: Current authenticated user
  * deviceId: Unique device identifier
  * userMasterKey: UMK for envelope encryption
  * database: LocalDatabaseService instance

Security Notes:
  - Backup UMK is encrypted with password-derived key
  - UMK is never logged or exposed
  - Password verified via backup decryption attempt
  - Device ID is persistent, cryptographically unique
  - Session is in-memory (cleared on logout)

Tests Added:
  - KDF verification on login
  - Password validation
  - Backup encryption/decryption
  - Session management

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 6: Local Encrypted Database
```
commit: database: Implement encrypted local CRUD operations

- Add LocalDatabaseService with Hive-CE
  * Manages encrypted local storage
  * Initializes Hive boxes for each record type
  * Takes UMK and deviceId for encryption context

- Implement CRUD for Record Types
  * Expense: createExpense(), readExpense(), listExpenses(), updateExpense(), deleteExpense()
  * Income: createIncome(), readIncome(), listIncome(), updateIncome(), deleteIncome()
  * Balance: createBalance(), readBalance(), listBalances()
  * Loan: createLoan(), readLoan(), listLoans(), updateLoan()
  * Investment: createInvestment(), readInvestment(), listInvestments()
  * Category: createCategory(), listCategories()

- Query Filtering
  * listExpenses: Filter by category, date range, amount range, payment method
  * listIncome: Filter by date range
  * Filtering applied after decryption for privacy

- Sync Queue Management
  * _addToSyncQueue: Record operation (create/update/delete)
  * getPendingSyncItems: Fetch pending operations
  * markSyncItemCompleted: Mark as synced

- Storage Format
  * Hive boxes store encrypted JSON strings
  * EncryptionEnvelope wraps each record
  * Metadata included for sync and conflict resolution

Security Notes:
  - Every operation encrypts with random DEK
  - WrongKey decryption fails (tamper proof)
  - Per-record encryption allows selective sync
  - Conflict versions preserved encrypted

Tests Added:
  - CRUD operations
  - Query filtering
  - Sync queue operations
  - Mock database for service tests

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 7: Data Models
```
commit: models: Define all financial record models

- Add Hive TypeId Models
  * Expense (0): Amount, category, subcategory, merchant, payment method, tags
  * Income (1): Amount, source, frequency (one-time/monthly/yearly)
  * Balance (2): Balance amount, effective date, source
  * Loan (3): Principal, outstanding, interest rate, repayment schedule
  * Investment (4): Instrument, type, units, prices, purchase date
  * Category (5): Name, color, icon, subcategories
  * SyncConflict (6): Conflicting versions for manual resolution
  * UserSession (7): Session metadata, last sync, device info

- Common Fields (All Models)
  * id: UUID
  * userId: Associated user
  * createdAt, updatedAt: Timestamps
  * deviceId: Creating device
  * syncStatus: pending/synced/conflict
  * version: For migrations

- Model-Specific Fields
  * Expense: Tags, merchant, reconciliation flag
  * Income: Frequency for recurring income
  * Loan: Interest rate, amortization schedule
  * Investment: Current price for P&L calculation

Tests Added:
  * Model serialization/deserialization
  * Hive adapter generation

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 8: GitHub Sync Service
```
commit: sync: Implement GitHub push/pull with conflict resolution

- Add GitHubSyncService
  * Requires GitHub PAT, repo owner, repo name
  * Uses Dio for REST API calls
  * Handles encrypted payload sync

- Push Implementation (pushChanges)
  * Collect all records (expenses, income, loans, investments, categories, balances)
  * Create sync envelope with all data
  * Encrypt with UMK
  * Upload to users/{userId}.json.enc
  * Handle file creation (first push) and updates (subsequent pushes)
  * Return SyncResult with record count

- Pull Implementation (pullChanges)
  * Download users/{userId}.json.enc from GitHub
  * Decrypt envelope with UMK
  * Merge each record:
    - If not exists locally: create
    - If newer remotely: update local
    - If newer locally: keep local (no action)
    - If same timestamp: mark conflict
  * Return merged record count

- Full Sync (fullSync)
  * Push local changes first
  * Then pull remote changes
  * Two-phase ensures bidirectional sync

- Utility Methods
  * isConfigured: Check if all required params set
  * verifyToken: Test GitHub PAT validity
  * getRepositoryInfo: Fetch repo metadata

- Data Classes
  * SyncResult: success, message, recordsSync, error, timestamp
  * RepositoryInfo: name, owner, isPrivate, stars, url

Security Notes:
  - Only encrypted payloads sent to GitHub
  - PAT stored encrypted in secure storage
  - No plaintext data in GitHub repo
  - Timestamps used for conflict detection
  - Conflicts preserved for manual resolution

Tests Added:
  - Configuration validation
  - SyncResult handling
  - RepositoryInfo parsing
  - Push/pull error cases

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 9: Security Tests
```
commit: test: Add comprehensive security and encryption tests

- KDF Tests
  * Consistency: Same inputs → same UMK
  * Uniqueness: Different passwords → different UMK
  * Uniqueness: Different salts → different UMK
  * Length: Output is 32 bytes
  * Wrapping key derivation

- Envelope Encryption Tests
  * Roundtrip: Encrypt → Decrypt → Original data
  * Tamper detection: Modified ciphertext → DecryptionException
  * Tamper detection: Modified AAD → DecryptionException
  * Wrong key: Wrong wrapping key → DecryptionException
  * JSON serialization: toJson → fromJson → consistency

- Password Validation Tests
  * Weak passwords: Rejected (too short, missing complexity)
  * Strong passwords: Accepted
  * Feedback: Real-time strength feedback
  * Scoring: Strength score 0-6 based on criteria

- Secure Random Tests
  * Length: Generated bytes match requested length
  * Randomness: Consecutive calls produce different values
  * Bounds: nextInt respects upper bound

- Integration Tests
  * Full encryption workflow
  * Metadata inclusion in AAD
  * JSON serialization/deserialization

Tests Added: 570+ lines
Target Coverage: >80% of core security code

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 10: GitHub Sync Tests
```
commit: test: Add GitHub sync service tests

- Configuration Tests
  * isConfigured: true when all params set
  * isConfigured: false when token missing
  * SyncResult structure and data
  * RepositoryInfo JSON parsing

- Error Handling Tests
  * pushChanges: Fails when not configured
  * pullChanges: Fails when not configured
  * Captures error messages

- Mock Database
  * MockLocalDatabaseService for unit tests
  * Implements all CRUD methods
  * Returns sample data for testing

Tests Added: 250+ lines
Integration ready for Milestone 2 UI testing

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 11: CI/CD Infrastructure
```
commit: ci: Setup GitHub Actions for test, build, deploy

- Flutter Test Job
  * Run all tests with coverage
  * Upload coverage to Codecov
  * Fail on test failures

- Lint Job
  * flutter analyze for code quality
  * Enforce style guidelines

- Web Build Job
  * flutter build web --release
  * Upload artifact for deployment

- Android Build Job
  * Setup Java 11
  * flutter build apk --release
  * Upload APK artifact

- Security Scan Job
  * TruffleHog for secret detection
  * Prevent committed credentials
  * Fail on secrets found

- Release Job (on main branch)
  * Automatic version tagging
  * Attach build artifacts
  * Create GitHub release

CI/CD Pipeline Status:
  - Automated on push to main/develop
  - Automated on pull requests to main
  - ~10 minutes total pipeline time

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 12: Documentation
```
commit: docs: Add comprehensive documentation

- README.md
  * Quick start (setup, run, build)
  * Feature overview
  * Security architecture summary
  * Installation instructions
  * GitHub PAT creation guide
  * User guide (all features)
  * Development guide
  * Testing instructions
  * Deployment
  * Troubleshooting
  * FAQ

- SECURITY.md
  * Monthly security audit checklist
  * Incident response procedures
  * Recovery procedures
  * Best practices
  * Threat model assumptions
  * Compliance notes

- ARCHITECTURE.md
  * 4-layer architecture explanation
  * Data flow diagrams
  * Security implementation details
  * Performance considerations
  * Testing strategy
  * Future enhancements

- .env.example
  * Configuration reference
  * GitHub integration
  * Security settings
  * Sync settings

- IMPLEMENTATION_STATUS.md
  * Milestone 1 completion status
  * Remaining work breakdown
  * Quick start for continuation
  * Implementation patterns
  * Timeline estimates

- DELIVERABLES.md
  * Complete file listing
  * Statistics and metrics
  * Acceptance criteria
  * Next steps

Total Documentation: 1,210+ lines
Coverage: Every feature documented

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

### Commit 13: Migration & Demo Tools
```
commit: tools: Add migration script and demo workflow

- Migration Script (migrate_from_csv.py)
  * Import from existing money managers
  * Support: Mint, YNAB, generic CSV
  * Amount parsing (handles currency symbols)
  * Date parsing (multiple formats)
  * Validation and error reporting
  * JSON export for app import
  * Command-line interface

- Demo Script (demo.sh)
  * Full workflow demonstration
  * Platform selection
  * Security verification
  * Next steps guidance
  * Interactive walkthrough

Usage:
  - python migrate_from_csv.py --input expenses.csv
  - bash tools/demo.sh

Co-authored-by: Copilot <223556219+copilot@users.noreply.github.com>
```

## Recommended Commit Message Format

For all future commits, use this format:

```
<type>: <subject>

<body>

<footer>

Co-authored-by: Your Name <email@example.com>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `test`: Test addition/modification
- `docs`: Documentation
- `perf`: Performance improvement
- `refactor`: Code refactoring
- `ci`: CI/CD changes
- `chore`: Build/dependency updates

### Example
```
feat: Add expense export to CSV

- Implement CSV export from expenses table
- Include filters in export (date range, category, etc.)
- Format as: Date, Amount, Category, Merchant, Notes
- Test with 1000+ expense records

Related to: Milestone 2 feature list
Co-authored-by: Your Team <team@example.com>
```

## Merging & Releases

### Feature Branches (for continuation)
```bash
git checkout -b feature/auth-ui
# Make changes
git commit -m "feat: Add login screen"
git push origin feature/auth-ui
# Create PR, get reviewed, merge to main
```

### Release Tags
```bash
# After Milestone 1
git tag -a v1.0.0-m1 -m "Milestone 1: Core Security Complete"

# After Milestone 2
git tag -a v1.0.0-m2 -m "Milestone 2: Authentication UI Complete"

# Final Release
git tag -a v1.0.0 -m "Money Manager v1.0.0 - Initial Release"
```

## Review Checklist

Before committing security code, ensure:
- [ ] No plaintext passwords
- [ ] No hardcoded API keys
- [ ] All sensitive data encrypted
- [ ] Proper exception handling
- [ ] Tests pass
- [ ] Comments on complex logic
- [ ] Error messages don't leak info
- [ ] Commit message explains "why", not just "what"

---

**This guide helps maintain code quality and security throughout the project lifecycle.**
