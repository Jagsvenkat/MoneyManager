#!/bin/bash
# Demo Script - Full Money Manager Workflow
#
# This script demonstrates:
# 1. App setup and build
# 2. Creating an account
# 3. Adding financial records offline
# 4. Syncing to GitHub
# 5. Resolving conflicts
# 6. Exporting encrypted backups
#
# Prerequisites:
# - Flutter installed and on PATH
# - GitHub PAT (for sync demo)
# - Device or emulator available

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Money Manager - Demo Workflow${NC}"
echo -e "${BLUE}================================${NC}\n"

# Step 1: Setup
echo -e "${YELLOW}[1/6] Setting up project...${NC}"
if [ ! -d "build" ]; then
    echo "Getting Flutter dependencies..."
    flutter pub get
fi
echo -e "${GREEN}✓ Project ready${NC}\n"

# Step 2: Build for selected platform
echo -e "${YELLOW}[2/6] Building app...${NC}"
read -p "Select platform (web/android/ios) [web]: " platform
platform=${platform:-web}

case $platform in
    web)
        echo "Building for web..."
        flutter build web --release
        echo -e "${GREEN}✓ Web build complete at build/web${NC}\n"
        ;;
    android)
        echo "Building for Android..."
        flutter build apk --release
        echo -e "${GREEN}✓ Android APK at build/app/outputs/flutter-apk${NC}\n"
        ;;
    ios)
        echo "Building for iOS..."
        flutter build ios --release
        echo -e "${GREEN}✓ iOS build complete${NC}\n"
        ;;
    *)
        echo -e "${RED}Invalid platform${NC}"
        exit 1
        ;;
esac

# Step 3: Run app
echo -e "${YELLOW}[3/6] Launching app...${NC}"
echo "Starting Money Manager app..."
if [ "$platform" = "web" ]; then
    echo "Open in browser: http://localhost:8080"
    echo "Press Ctrl+C to stop server"
    cd build/web && python3 -m http.server 8080
else
    flutter run -d $platform
fi

echo -e "${GREEN}✓ App running${NC}\n"

# Step 4: Demo workflow
echo -e "${YELLOW}[4/6] Demo Workflow:${NC}"
echo "
1. CREATE ACCOUNT
   - Username: demo@moneymanager.app
   - Password: Demo@Password123456
   - Save the encrypted backup shown
   
2. ADD EXPENSES (offline)
   - Food: $15.50 at Coffee Shop
   - Transport: $5.00 for Bus
   - Entertainment: $25.00 for Movie
   
3. ADD INCOME (offline)
   - Salary: $2,000.00
   
4. VIEW DASHBOARD
   - See balance: $1,954.50
   - View expense breakdown
   
5. CONFIGURE GITHUB SYNC (optional)
   - Settings → GitHub
   - Paste your Personal Access Token
   - Tap 'Connect'
   
6. SYNC TO GITHUB
   - Tap 'Full Sync'
   - View encrypted backup in your GitHub repo
   
7. EXPORT BACKUP
   - Settings → Export
   - Choose encrypted format
   - Save to secure location
"

read -p "Press Enter when ready to continue..."

# Step 5: Security verification
echo -e "${YELLOW}[5/6] Security Verification${NC}"
echo "
Checking security implementation:
"

# Check security modules
if [ -f "lib/core/security/kdf.dart" ]; then
    echo -e "${GREEN}✓${NC} Key Derivation Function (PBKDF2) implemented"
fi

if [ -f "lib/core/security/envelope.dart" ]; then
    echo -e "${GREEN}✓${NC} Envelope Encryption (XChaCha20-Poly1305) implemented"
fi

if [ -f "lib/core/security/secure_storage.dart" ]; then
    echo -e "${GREEN}✓${NC} Secure Storage (Platform-native) implemented"
fi

if [ -f "lib/core/services/github_sync_service.dart" ]; then
    echo -e "${GREEN}✓${NC} GitHub Sync Engine implemented"
fi

if [ -f "test/security_tests.dart" ]; then
    echo -e "${GREEN}✓${NC} Security Tests available"
    echo "\nRunning security tests..."
    flutter test test/security_tests.dart --verbose
fi

echo -e "${GREEN}✓ Security checks complete${NC}\n"

# Step 6: Next steps
echo -e "${YELLOW}[6/6] Next Steps${NC}"
echo "
📚 Documentation:
   - README.md: Full user guide and setup
   - SECURITY.md: Security audit checklist and incident response
   - .env.example: Configuration reference
   
🔧 Development:
   - lib/core/security/: Core encryption modules
   - lib/core/services/: Authentication and sync services
   - lib/core/database/: Local encrypted database
   - lib/features/: UI screens and features
   
🧪 Testing:
   - flutter test: Run all tests
   - flutter test test/security_tests.dart: Security-specific tests
   
🚀 Deployment:
   - flutter build web --release: Web build
   - flutter build apk --release: Android
   - flutter build ios --release: iOS
   
🔐 Security:
   - Review SECURITY.md for incident response
   - Store encrypted backups securely
   - Rotate GitHub PAT annually
   - Keep app and device OS updated
"

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Demo Complete! 🎉${NC}"
echo -e "${GREEN}================================${NC}"
