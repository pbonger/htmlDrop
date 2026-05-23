# HTML Drop — WebStorm Plugin

## Project overview

A WebStorm plugin that adds **Share on HTML Drop** to the right-click context menu for `.html` files. It uploads the file to [pagedrop.io](https://pagedrop.io) via their JSON API (no auth required), copies the resulting URL to clipboard, and shows a balloon notification. Optionally encrypts the page with a password using AES-256-GCM before uploading.

## Stack

- **Language:** Kotlin
- **Build:** Gradle with `org.jetbrains.intellij.platform` plugin v2.3.0
- **Target IDE:** WebStorm 2024.3 (build 243), JVM toolchain 21
- **Build scripts:** `npm run install` / `npm run build` (npm wraps Gradle)

## Build commands

```bash
npm install     # installs Gradle + JDK 21 via Homebrew, generates Gradle wrapper
npm run build   # compiles and packages → build/distributions/html-drop-plugin-1.0.9.zip
```

Install the zip in WebStorm → Settings → Plugins → gear → Install Plugin from Disk.

## Key files

| File | Purpose |
|---|---|
| `build.gradle.kts` | Gradle build — IntelliJ platform 2.x config, JVM 21, instrumentation disabled |
| `package.json` | npm wrapper with build, release, and finder scripts |
| `src/main/kotlin/htmldrop/ShareOnHTMLDropAction.kt` | Main action — context menu handler, upload, encryption |
| `src/main/kotlin/htmldrop/PasswordDialog.kt` | Dialog with `JPasswordField` shown before each upload |
| `src/main/resources/META-INF/plugin.xml` | Plugin descriptor — id, vendor, action registration |
| `src/main/resources/META-INF/pluginIcon.png` | Plugin icon shown in WebStorm plugin settings (40×40) |
| `src/main/resources/icons/icon16.png` | Action icon shown in context menu (16×16) |

## Finder Quick Action (`finder/`)

A companion macOS Automator workflow that adds **Share on HTML Drop** to Finder's right-click Quick Actions for `.html` files.

| File | Purpose |
|---|---|
| `finder/Sources/HTMLDropCore.swift` | Upload, encryption, clipboard, helpers |
| `finder/Sources/main.swift` | CLI entry point — dialogs, notification, calls core |
| `finder/Extension/ShareViewController.swift` | Share extension variant (used by the `.app`) |
| `finder/Package.swift` | Swift package — builds `html-drop` binary |
| `finder/HTMLDrop.workflow/` | Automator workflow bundle installed to `~/Library/Services/` |
| `finder/HTMLDrop.app/` | Pre-built macOS share extension app |
| `finder/install.sh` | Builds + installs the workflow and binary |
| `finder/build-app.sh` | Builds the `.app` share extension |

```bash
npm run build:finder    # compiles Swift binary and copies into workflow bundle
npm run package:finder  # zips to build/distributions/HTMLDrop.workflow.zip
npm run install:finder  # builds and installs to ~/Library/Services/
```

## How the plugin works

### Action flow
1. User right-clicks an `.html` file → **Share on HTML Drop**
2. `PasswordDialog` appears — enter a password or leave empty and click Share
3. Background task (`Task.Backgroundable`) starts:
   - If password given: encrypts HTML with AES-256-GCM, wraps in a self-contained password-prompt HTML page
   - POSTs `{"html": "..."}` to `https://pagedrop.io/api/upload` (no auth required)
   - Parses URL from JSON response
   - Copies URL to clipboard, shows balloon notification with "Open in Browser" action

### Upload (`ShareOnHTMLDropAction.upload`)
- `POST https://pagedrop.io/api/upload`
- `Content-Type: application/json`, body: `{"html": "<escaped html content>"}`
- Response: JSON with a `url` field containing the public page URL
- No authentication, no ZIP, instant deploy

### Encryption (`ShareOnHTMLDropAction.encrypt`)
- Key derivation: PBKDF2WithHmacSHA256, 100k iterations, 256-bit key
- Encryption: AES/GCM/NoPadding with random 16-byte salt and 12-byte IV
- Output: self-contained HTML wrapper with encrypted content as base64, decrypted client-side using the Web Crypto API

## Known build quirks

- `instrumentCode` and `buildSearchableOptions` are disabled in `build.gradle.kts` — `java-compiler-ant-tasks` for WebStorm build 243 is not available in JetBrains repos
- `compileOnly(kotlin("stdlib"))` prevents stdlib version conflicts with the IntelliJ Platform
- The Gradle wrapper targets Gradle 8.8; system Gradle (9.x) is only used to generate the wrapper via `npm install`
