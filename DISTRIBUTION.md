# Distributing App Scheduler

App Scheduler is distributed **outside the Mac App Store** using a **Developer ID**
certificate — the same approach used by Homebrew, Alfred, Bartender, and most
power-user menu-bar utilities.

This document covers everything from getting your Apple Developer account to
having a notarized `.dmg` automatically published to GitHub Releases.

---

## Table of Contents

1. [One-time setup](#1-one-time-setup)
2. [Update the project with your details](#2-update-the-project-with-your-details)
3. [Option A — Automatic release via GitHub Actions](#3-option-a--automatic-release-via-github-actions)
4. [Option B — Local build and release](#4-option-b--local-build-and-release)
5. [What users see](#5-what-users-see)
6. [Updating the app](#6-updating-the-app)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. One-time setup

### 1a. Join the Apple Developer Program

- Go to [developer.apple.com](https://developer.apple.com) and enrol ($99/year)
- Once approved, note your **Team ID** — find it at
  [developer.apple.com/account](https://developer.apple.com/account) under
  Membership Details. It looks like `ABC1234XYZ` (10 characters)

### 1b. Create a Developer ID Application certificate

In Xcode:
1. Open **Xcode → Settings → Accounts**
2. Select your Apple ID → click **Manage Certificates**
3. Click **+** → choose **Developer ID Application**
4. Xcode creates and installs the certificate in your Keychain automatically

### 1c. Export the certificate (for GitHub Actions only)

If you want the GitHub Actions workflow to sign your builds, you need to export
the certificate as a `.p12` file:

1. Open **Keychain Access** → find **Developer ID Application: Your Name**
2. Right-click → **Export** → choose `.p12` format
3. Set a strong password — you'll need it later
4. Base64-encode it for GitHub:
   ```bash
   base64 -i ~/Desktop/DeveloperID.p12 | pbcopy
   ```
   This copies the encoded cert to your clipboard.

### 1d. Create an app-specific password for notarytool

1. Go to [appleid.apple.com](https://appleid.apple.com) → Sign In
2. Under **App-Specific Passwords**, click **+**
3. Name it `notarytool` and save the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

---

## 2. Update the project with your details

Open `swift-app/AppScheduler.xcodeproj` in Xcode and change **two things**:

### Bundle Identifier
In the project settings under **Signing & Capabilities**, change:
```
com.yourcompany.appscheduler
```
to something you own, e.g.:
```
com.johndoe.appscheduler
```

### Team ID  
In the same panel, select your Apple Developer Team from the dropdown.

> **Alternatively**, find and replace `YOUR_TEAM_ID` and `com.yourcompany.appscheduler`
> in `swift-app/AppScheduler.xcodeproj/project.pbxproj` directly.

---

## 3. Option A — Automatic release via GitHub Actions

Every time you push a version tag, GitHub builds, signs, notarizes, and
publishes a release automatically. Zero manual steps after initial setup.

### 3a. Add GitHub Secrets

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**
and add all five:

| Secret name | Value |
|---|---|
| `APPLE_TEAM_ID` | Your 10-char Team ID, e.g. `ABC1234XYZ` |
| `DEVELOPER_ID_CERT_BASE64` | Base64-encoded `.p12` from step 1c |
| `DEVELOPER_ID_CERT_PASSWORD` | Password you set on the `.p12` |
| `NOTARYTOOL_APPLE_ID` | Your Apple ID email |
| `NOTARYTOOL_APP_PASSWORD` | App-specific password from step 1d |
| `NOTARYTOOL_TEAM_ID` | Same as `APPLE_TEAM_ID` |

### 3b. Push a release tag

```bash
git add .
git commit -m "Release v1.9.0"
git tag v1.9.0
git push origin main --tags
```

GitHub Actions will:
1. ✅ Build a Release archive with Hardened Runtime
2. ✅ Sign with your Developer ID certificate
3. ✅ Submit to Apple's notarization service (takes ~2 min)
4. ✅ Staple the notarization ticket to the `.app`
5. ✅ Package a signed `.dmg` with a drag-to-Applications layout
6. ✅ Notarize and staple the `.dmg` too
7. ✅ Create a GitHub Release with the `.dmg` attached

You can watch the progress in the **Actions** tab of your repo.

---

## 4. Option B — Local build and release

If you prefer to build on your own machine:

```bash
# Set your credentials (or export them in your shell profile)
export TEAM_ID="ABC1234XYZ"
export BUNDLE_ID="com.yourcompany.appscheduler"
export APPLE_ID="you@example.com"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # app-specific password

# Run the build script from the repo root
./scripts/build-release.sh
```

The script produces `build/AppScheduler.dmg` — signed, notarized, and ready
to distribute. Upload it to GitHub Releases, your website, or anywhere else.

---

## 5. What users see

Because the app is signed with a Developer ID and notarized by Apple:

- **No Gatekeeper warning** — the app opens normally, no right-click-to-open needed
- **No "unidentified developer" dialog** — users get the standard launch confirmation
- The app shows **"App Scheduler" by "Your Name"** in System Settings → Privacy

---

## 6. Updating the app

1. Make your code changes
2. Bump the version in `Info.plist` (`CFBundleShortVersionString`) and in
   `project.pbxproj` (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`)
3. Tag and push:
   ```bash
   git tag v1.10.0
   git push origin main --tags
   ```
4. GitHub Actions handles the rest

---

## 7. Troubleshooting

### "No signing certificate found"
- Make sure your Developer ID Application cert is in your login Keychain
- Run `security find-identity -v -p codesigning` — you should see it listed

### Notarization fails with "The software is not signed"
- Ensure `ENABLE_HARDENED_RUNTIME = YES` in the Release build config
- Ensure `OTHER_CODE_SIGN_FLAGS = "--timestamp --options=runtime"` is set
- These are already configured in the project file ✅

### GitHub Actions: "error: No profile for team ... matching ..."
- This is normal — we use `CODE_SIGN_STYLE=Manual` which doesn't need a
  provisioning profile for Developer ID distribution
- Ensure `PROVISIONING_PROFILE_SPECIFIER = ""` in Release config ✅

### "xcrun: error: invalid active developer path"
- Run `xcode-select --install` or `sudo xcode-select -r` on your Mac
- In GitHub Actions, the `sudo xcode-select -s` step handles this ✅

### Stapling fails after notarization
- Wait a few minutes — Apple's CDN can take time to propagate the ticket
- Re-run `xcrun stapler staple "App Scheduler.app"` manually

---

## Architecture Summary

```
Your Mac / GitHub Actions
        │
        ▼
  xcodebuild archive          ← Compiles + signs with Developer ID cert
        │
        ▼
  xcodebuild -exportArchive   ← Packages .app with Developer ID method
        │
        ▼
  xcrun notarytool submit     ← Sends zip to Apple, waits for approval
        │
        ▼
  xcrun stapler staple        ← Attaches approval ticket to .app
        │
        ▼
  create-dmg                  ← Packages .app into drag-to-install .dmg
        │
        ▼
  codesign + notarytool       ← Signs and notarizes the .dmg itself
        │
        ▼
  GitHub Release              ← .dmg published, users download directly
```
