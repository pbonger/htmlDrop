# Netlify Share — WebStorm Plugin

## Project overview

A WebStorm plugin that adds **Share on Netlify** to the right-click context menu for `.html` files. It zips the file, uploads it to Netlify via their REST API, copies the resulting URL to clipboard, and shows a balloon notification. Optionally encrypts the page with a password using AES-256-GCM before uploading.

## Stack

- **Language:** Kotlin
- **Build:** Gradle with `org.jetbrains.intellij.platform` plugin v2.3.0
- **Target IDE:** WebStorm 2024.3 (build 243), JVM toolchain 21
- **Build scripts:** `npm run install` / `npm run build` (npm wraps Gradle)

## Build commands

```bash
npm install     # installs Gradle + JDK 21 via Homebrew, generates Gradle wrapper
npm run build   # compiles and packages → build/distributions/netlify-share-plugin-1.0.0.zip
```

Install the zip in WebStorm → Settings → Plugins → gear → Install Plugin from Disk.

## Key files

| File | Purpose |
|---|---|
| `build.gradle.kts` | Gradle build — IntelliJ platform 2.x config, JVM 21, instrumentation disabled |
| `package.json` | npm wrapper with `install` and `build` scripts |
| `src/main/kotlin/netlifyshare/ShareOnNetlifyAction.kt` | Main action — context menu handler, upload, encryption |
| `src/main/kotlin/netlifyshare/NetlifyAuthManager.kt` | Netlify OAuth 2.0 flow — browser login, local callback server, token storage |
| `src/main/kotlin/netlifyshare/PasswordDialog.kt` | Dialog with `JPasswordField` shown before each upload |
| `src/main/kotlin/netlifyshare/Credentials.kt` | OAuth client ID + secret — **gitignored, must be created manually** |
| `src/main/resources/META-INF/plugin.xml` | Plugin descriptor — id, vendor, action registration |
| `src/main/resources/META-INF/pluginIcon.png` | Plugin icon shown in WebStorm plugin settings (40×40) |
| `src/main/resources/META-INF/pluginIcon@2x.png` | Retina plugin icon (80×80) |
| `src/main/resources/icons/icon16.png` | Action icon shown in context menu (16×16) |

## Credentials setup

`Credentials.kt` is gitignored. Anyone building from source must create it:

```kotlin
package netlifyshare

internal const val NETLIFY_CLIENT_ID     = "your_client_id"
internal const val NETLIFY_CLIENT_SECRET = "your_client_secret"
```

Get credentials from **app.netlify.com → User Settings → Applications → OAuth Apps**.  
Redirect URL must be set to `http://localhost`.

## How the plugin works

### Action flow
1. User right-clicks an `.html` file → **Share on Netlify**
2. `PasswordDialog` appears — enter a password or leave empty and click Share
3. Background task (`Task.Backgroundable`) starts:
   - Checks keychain for a stored Netlify token via `NetlifyAuthManager.getToken()`
   - If none: calls `NetlifyAuthManager.login()` which opens browser + captures OAuth callback
   - If password given: encrypts HTML with AES-256-GCM, wraps in a self-contained password-prompt HTML page
   - Zips the file, POSTs to `https://api.netlify.com/api/v1/sites` with `Authorization: Bearer <token>`
   - Copies URL to clipboard, shows balloon notification

### OAuth flow (`NetlifyAuthManager`)
1. Finds a free local port via `ServerSocket(0)`
2. Starts a background thread with a `ServerSocket` listening on that port
3. Opens browser to `https://app.netlify.com/authorize?response_type=code&...&redirect_uri=http://localhost:<port>`
4. Captures the `?code=` from the GET request to the local server
5. Exchanges code for token via POST to `https://api.netlify.com/oauth/token`
6. Stores token in IntelliJ's `PasswordSafe` (macOS keychain) — persists across restarts

### Encryption (`ShareOnNetlifyAction.encrypt`)
- Key derivation: PBKDF2WithHmacSHA256, 100k iterations, 256-bit key
- Encryption: AES/GCM/NoPadding with random 16-byte salt and 12-byte IV
- Output: self-contained HTML wrapper with encrypted content as base64, decrypted client-side using the Web Crypto API

## Known build quirks

- `instrumentCode` and `buildSearchableOptions` are disabled in `build.gradle.kts` — `java-compiler-ant-tasks` for WebStorm build 243 is not available in JetBrains repos
- `compileOnly(kotlin("stdlib"))` prevents stdlib version conflicts with the IntelliJ Platform
- The Gradle wrapper targets Gradle 8.8; system Gradle (9.x) is only used to generate the wrapper via `npm install`
- `Credentials.kt` must exist before running `npm run build` or compilation will fail

## Sharing the plugin

Distribute `build/distributions/netlify-share-plugin-1.0.0.zip` directly. The OAuth credentials are compiled into the JAR — do not publish the source with `Credentials.kt` present.
