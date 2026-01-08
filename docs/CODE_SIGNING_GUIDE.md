# Code Signing Setup Guide

This guide explains how to set up digital code signing for DRL Community Edition installers.

## Overview

| Platform | Certificate Type | Cost | Status |
|----------|-----------------|------|--------|
| 🪟 Windows | Authenticode Code Signing | ~$200-500/year | Optional |
| 🍎 macOS | Apple Developer ID | $99/year | Optional |
| 🐧 Linux | GPG Signing | Free | Optional |

Without signing, users will see security warnings but can still install.

---

## Windows Code Signing

### 1. Get a Code Signing Certificate

Purchase from a trusted Certificate Authority:
- [DigiCert](https://www.digicert.com/signing/code-signing-certificates) (~$474/year)
- [Sectigo](https://sectigo.com/ssl-certificates-tls/code-signing) (~$199/year)
- [SSL.com](https://www.ssl.com/certificates/ev-code-signing/) (~$239/year)

**Note:** EV (Extended Validation) certificates provide better SmartScreen reputation but require hardware tokens.

### 2. Export Certificate to PFX

```powershell
# Export from Windows Certificate Store
$cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*Your Company*" }
Export-PfxCertificate -Cert $cert -FilePath certificate.pfx -Password (ConvertTo-SecureString -String "your-password" -Force -AsPlainText)
```

### 3. Convert to Base64

```bash
base64 -w 0 certificate.pfx > certificate_base64.txt
```

### 4. Add GitHub Secrets

Go to: `Settings → Secrets and variables → Actions → New repository secret`

| Secret Name | Value |
|-------------|-------|
| `WINDOWS_CERT_BASE64` | Contents of certificate_base64.txt |
| `WINDOWS_CERT_PASSWORD` | Your PFX password |

---

## macOS Code Signing & Notarization

### 1. Join Apple Developer Program

1. Go to [developer.apple.com](https://developer.apple.com)
2. Enroll in Apple Developer Program ($99/year)
3. Wait for approval (usually 24-48 hours)

### 2. Create Developer ID Certificate

1. Open Xcode → Preferences → Accounts
2. Select your team → Manage Certificates
3. Click + → Developer ID Installer

Or via command line:
```bash
# List existing identities
security find-identity -v -p codesigning

# The identity looks like:
# "Developer ID Installer: Your Name (TEAM_ID)"
```

### 3. Export Certificate

```bash
# Export from Keychain
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities -f pkcs12 -P "password" -o developer_id.p12

# Convert to base64
base64 -i developer_id.p12 -o certificate_base64.txt
```

### 4. Create App-Specific Password

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign In → Security → App-Specific Passwords
3. Generate new password for "GitHub Actions"

### 5. Add GitHub Secrets

| Secret Name | Value |
|-------------|-------|
| `APPLE_CERT_BASE64` | Contents of certificate_base64.txt |
| `APPLE_CERT_PASSWORD` | Your P12 password |
| `APPLE_SIGNING_IDENTITY` | `Developer ID Installer: Your Name (TEAM_ID)` |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_APP_PASSWORD` | App-specific password from step 4 |
| `APPLE_TEAM_ID` | Your 10-character Team ID |

---

## Linux GPG Signing

### 1. Generate GPG Key

```bash
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, no expiration
# Enter name and email
```

### 2. Export Keys

```bash
# Export public key (share this)
gpg --armor --export your@email.com > public.asc

# Export private key (keep secret!)
gpg --armor --export-secret-keys your@email.com > private.asc

# Convert to base64
base64 -w 0 private.asc > gpg_private_base64.txt
```

### 3. Add GitHub Secrets

| Secret Name | Value |
|-------------|-------|
| `GPG_PRIVATE_KEY` | Contents of gpg_private_base64.txt |
| `GPG_PASSPHRASE` | Your GPG key passphrase |

---

## Verifying Signatures

### Windows
```powershell
# Check signature
Get-AuthenticodeSignature "DRL-Community-Setup.exe"
```

### macOS
```bash
# Check signature
codesign -dv --verbose=4 DRL-Community.pkg

# Check notarization
spctl -a -vv DRL-Community.pkg
```

### Linux
```bash
# Import public key
gpg --import public.asc

# Verify signature
gpg --verify DRL-Community.AppImage.sig DRL-Community.AppImage
```

---

## Cost-Free Alternatives

If you don't want to pay for certificates:

### Windows
- Users will see SmartScreen warning ("Windows protected your PC")
- They can click "More info" → "Run anyway"
- After enough installs, reputation builds automatically

### macOS
- Users will see Gatekeeper warning ("cannot be opened")
- They can right-click → Open → Open anyway
- Or: `xattr -cr /path/to/app` in Terminal

### Linux
- AppImages don't require signing
- Users can verify SHA256 checksums instead

---

## Checksums (Alternative to Signing)

If not using code signing, provide SHA256 checksums:

```bash
# Generate checksums
sha256sum *.exe *.pkg *.AppImage > checksums.sha256

# Upload checksums.sha256 with release
```

Users verify with:
```bash
sha256sum -c checksums.sha256
```

---

## Questions?

Open an issue: https://github.com/Georgeandrew7/DRL-Simulator-Community/issues
