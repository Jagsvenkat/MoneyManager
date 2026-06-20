# Security Audit Checklist & Incident Response

## Security Audit Checklist

Run through this checklist regularly (monthly recommended).

### User & Authentication
- [ ] Password is at least 12 characters
- [ ] Password contains uppercase, lowercase, numbers, and special characters
- [ ] No password written down or shared
- [ ] Encrypted backup from registration stored securely
- [ ] Biometric unlock is enabled (optional but recommended)
- [ ] No other users have physical access to device

### GitHub Configuration
- [ ] GitHub PAT is configured if using sync
- [ ] GitHub PAT has only necessary scopes (repo access)
- [ ] GitHub PAT expiration is set (1 year maximum)
- [ ] PAT is not stored plaintext (encrypted by app)
- [ ] Repository is private
- [ ] Only trusted devices added to account

### Local Device
- [ ] Device OS is up to date with latest security patches
- [ ] App is on latest version
- [ ] No jailbreak (iOS) or root (Android) modifications
- [ ] Device screen lock enabled
- [ ] Device encryption enabled (standard on modern iOS/Android)
- [ ] No debug/developer mode enabled in production

### Data Backups
- [ ] Encrypted backup file stored in secure location
- [ ] Backup file not shared via email or unencrypted cloud
- [ ] Recovery password tested (optional: on secondary device)
- [ ] No plaintext exports without encryption enabled
- [ ] Sync history reviewed for unauthorized changes

### Sync & Connectivity
- [ ] Only connect to trusted WiFi networks
- [ ] VPN considered for public WiFi sync
- [ ] GitHub sync conflicts resolved (none pending)
- [ ] Last successful sync was recent
- [ ] No unexpected changes in pulled data

### App Settings
- [ ] Session timeout set appropriately
- [ ] Notification privacy enabled (minimal sensitive data in notifications)
- [ ] Analytics disabled (no data collection)
- [ ] Auto-fill disabled for password fields

### Periodic Actions
- [ ] Password changed at least annually (or if suspected compromise)
- [ ] GitHub PAT rotated at least annually
- [ ] Old backups securely deleted after new ones created
- [ ] Device checked for unauthorized access patterns

---

## Incident Response Procedures

### Incident: Suspected Password Compromise

**Immediate Actions (< 5 minutes)**:
1. If on home network, immediately logout and close app
2. Switch to different device/network if possible
3. Change password immediately:
   - Open app → Settings → Security → Change Password
   - Enter old password (verify identity)
   - Enter NEW strong password (12+ chars, all requirements)
   - Confirm new password
   - **UMK is re-encrypted automatically**

**Post-Incident (within 1 hour)**:
4. Monitor account for unauthorized changes:
   - Check expense/income history for unfamiliar entries
   - Review GitHub sync history (Settings → Sync History)
   - Check GitHub account activity at github.com
5. If unauthorized changes found:
   - Create new encrypted backup (Settings → Export Backup)
   - Consider importing to new account (see below)

**Recovery (if needed)**:
6. Logout of app completely
7. Create new account with new strong password
8. Import encrypted backup from old account (Settings → Import)
9. Delete old account data if confident it's compromised

**Prevention**:
- Enable biometric lock (Settings → Security)
- Set device timeout to 1-2 minutes
- Consider rotating GitHub PAT if sync was active during compromise

---

### Incident: Device Lost or Stolen

**Before Losing Device**:
- Enable device encryption (default on modern iOS/Android)
- Set strong device PIN/biometric
- Enable Find My Device (iPhone Find My / Android Find My Device)

**After Device Lost**:
1. **Data is secure** - encrypted with your password, unreadable without it
2. Login on new device:
   - Download Money Manager from App Store
   - Open app → Create Account or Login
   - If new account: app creates new session (isolated)
   - If login to existing: pull data from GitHub (if sync enabled)
3. Optionally remote-wipe lost device via manufacturer
4. Consider password change (optional, data already encrypted)
5. Monitor sync history for unauthorized access attempts

---

### Incident: Suspected GitHub PAT Compromise

**Immediate Actions**:
1. Go to github.com → Settings → Personal Access Tokens
2. Find the compromised PAT
3. Click "Revoke" immediately
4. Generate new PAT with same scopes:
   - Go to Settings → Tokens (classic)
   - Click "Generate new token"
   - Select "repo" scope (full access to private repos)
   - Set expiration (1 year recommended)
   - Copy new token
5. In app: Settings → GitHub → Update PAT
   - Paste new token
   - Tap "Save"
6. Perform full sync (Settings → Sync → Full Sync)

**Post-Incident**:
7. Review GitHub repo for unauthorized changes:
   - Go to repo → Commits
   - Check for unexpected pushes
   - Check for file modifications
8. If repo was modified:
   - Export encrypted backup (Settings → Export Backup)
   - Create new repo
   - Manually review/clean data before syncing

**Prevention**:
- Rotate PAT every 6 months
- Set PAT expiration to 1 year maximum
- Review GitHub settings monthly
- Don't share PAT with others

---

### Incident: Data Corruption or Sync Conflicts

**Detection**:
- Sync shows conflicts (Settings → Sync Conflicts)
- Missing or changed records after sync
- App crashes during sync/decryption

**Recovery**:
1. Check sync history (Settings → Sync History)
   - Identify when corruption started
   - Note last known-good sync timestamp
2. Resolve conflicts:
   - Settings → Sync Conflicts
   - For each conflict: compare versions and choose one
   - Tap "Resolve" to proceed
3. If still seeing corruption:
   - Export encrypted backup (Settings → Export Backup)
   - Create new account
   - Import from backup
   - Verify data integrity before resuming sync
4. Report issue on GitHub with:
   - Device/OS version
   - App version
   - Approximate sync time
   - Do NOT include plaintext data

**Prevention**:
- Avoid editing on multiple devices simultaneously
- Wait for sync completion before switching devices
- Review pulled changes before confirming sync
- Keep encrypted backups of important exports

---

### Incident: Forgotten Password

**Recovery**:
1. Unfortunately, **there is no password reset**
   - This is intentional for security (only you can decrypt data)
2. If you have encrypted backup from registration:
   - Create new account
   - Settings → Import → Select encrypted backup file
   - App will prompt for password used during backup
   - If correct password: data imported with new account
3. If no backup available:
   - **All data is lost permanently** (encrypted with lost password)
   - Create new account and start fresh
   - This is the security tradeoff for offline encryption

**Prevention**:
- Write down password in secure location (password manager recommended)
- Test recovery process on secondary device before losing access
- Store encrypted backup in multiple secure locations
- Enable device biometric unlock so you don't need password frequently

---

### Incident: Regulatory/Audit Request for Data

**In-App Data Deletion** (hard delete, not recoverable):
1. Settings → Privacy → Delete All Data
2. Confirm with password
3. **All local data permanently deleted**
4. If sync was enabled: GitHub file remains (encrypted, unreadable)
5. GitHub file can be deleted from repo directly if needed

**GitHub File Deletion**:
1. Go to GitHub repo
2. Navigate to `users/{userId}.json.enc`
3. Click "..." → Delete file
4. Confirm deletion

**Data Export for Compliance**:
1. Settings → Export → Encrypted or Plaintext
2. If plaintext: password required (biometric unlock)
3. Export includes all records in selected date range
4. File suitable for sharing with auditors (if plaintext)
5. If encrypted: provide decryption key separately if needed

---

## Recovery Procedures

### Full Account Recovery

If you have access to encrypted backup:

```
1. New Device/Account Recovery
   - Install Money Manager
   - Tap "Import Existing Data"
   - Select encrypted backup file
   - Enter password from original account
   - Data imported and encrypted with new password
   - Verify all records appear correctly

2. Sync with GitHub
   - Settings → GitHub
   - Enter GitHub PAT (or generate new one)
   - Tap "Full Sync"
   - Resolve any conflicts
```

### Partial Recovery (Lost Some Data)

If local data is deleted but GitHub backup exists:

```
1. Create new account
2. Settings → GitHub → Configure PAT
3. Tap "Pull from GitHub"
4. Review and merge pulled records
5. Create new encrypted backup
```

### Emergency Data Access

If you need to recover data from device but app is non-functional:

```
1. If Hive DB is accessible:
   - Files located in app's documents directory
   - Envelopes are stored as JSON in boxes
   - Encrypted; cannot read without UMK
   
2. If GitHub backup accessible:
   - File at users/{userId}.json.enc
   - Encrypted envelope format
   - Can be decrypted with UMK + wrapping key derivation
```

---

## Security Best Practices

### Daily Habits
- Use strong, unique passwords
- Keep OS and apps updated
- Review sync history weekly
- Don't share devices unless necessary
- Lock device when stepping away

### Monthly
- Run security audit checklist
- Review GitHub activity
- Check for app updates
- Verify sync status

### Quarterly
- Test recovery procedures
- Update GitHub PAT (if quarterly rotation desired)
- Export and verify encrypted backup
- Review permission/access logs

### Annually
- Change password
- Rotate GitHub PAT
- Full security audit
- Review all synced data for anomalies

---

## Threat Model Assumptions

This app is designed against these threats:

**Protected Against**:
- Passive data theft (encrypted at rest)
- Eavesdropping (TLS + encryption in transit)
- Unauthorized app access (password + optional biometric)
- Device theft (encrypted data unreadable)
- GitHub repo exposure (encrypted envelopes only)
- Malicious sync (conflicts preserved, last-write-wins with timestamps)

**NOT Protected Against** (out of scope):
- Keyloggers/spyware on device
- Physical torture to extract password
- Quantum computers (future)
- Bugs in underlying crypto libraries
- Zero-day vulnerabilities in Flutter/Dart
- Compromised device OS

**Assumptions**:
- Device OS is trusted and up-to-date
- At least one secure location for password storage
- User follows password best practices
- GitHub account security is user's responsibility

---

## Contact & Reporting Security Issues

If you discover a security vulnerability:

1. **Do NOT post publicly** on GitHub issues
2. Email: [security contact email]
3. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (optional)
4. **Do NOT share**:
   - Plaintext user data
   - Test credentials
   - Sensitive configuration

## Compliance Notes

- **GDPR**: No user data collected beyond what's stored locally/GitHub
- **Data Retention**: User controls (can export, delete anytime)
- **Encryption Standard**: NIST-approved algorithms (PBKDF2, XChaCha20-Poly1305)
- **Audit Trail**: GitHub commit history provides sync audit trail
- **Data Location**: User's device + user's GitHub repo (no third-party servers)

---

**Last Updated**: 2024  
**Version**: 1.0.0  
**Review Frequency**: Quarterly
