# HTML Drop

Share any `.html` file to [pagedrop.io](https://pagedrop.io) in one click — from WebStorm or the macOS Finder Share menu. No sign-up, no auth token. Optionally encrypt pages with a password before uploading.

---

## What's in the repo

| Path | What it is |
|---|---|
| `src/main/kotlin/htmldrop/` | WebStorm plugin (Kotlin) |
| `finder/Sources/` | Swift CLI (SPM package) used by the Finder Quick Action |
| `finder/Extension/` | macOS Share Extension (shown in Finder's Share button) |
| `finder/App/` | Minimal host app required to carry the Share Extension |
| `finder/HTMLDrop.workflow/` | Automator Quick Action — installs to `~/Library/Services/` |
| `finder/build-app.sh` | Compiles + bundles + signs `HTMLDrop.app` |
| `finder/pkg-scripts/postinstall` | Runs as root after `.pkg` install |
| `scripts/generate-dmg-bg.swift` | Draws the DMG window background (pure Swift, no deps) |
| `scripts/package-dmg.sh` | Builds the `.pkg`, assembles the DMG with background |
| `build.gradle.kts` | Gradle config for the WebStorm plugin |
| `package.json` | All build / release commands |

---

## npm scripts (run everything from project root)

```bash
npm run build          # compile WebStorm plugin → build/distributions/html-drop-plugin-*.zip
npm run build:app      # compile + bundle + sign HTMLDrop.app (Share Extension)
npm run update:app     # build:app, install to /Applications, re-register extension
npm run icon           # regenerate all icons from source (see Icon sources below)
npm run package:pkg    # build .pkg only (no DMG)
npm run package:all    # build .pkg + zip bundle (plugin zip + pkg, no DMG)
npm run package:dmg    # build .pkg and assemble final DMG (used by release)
npm run release        # bump patch version, build everything, push DMG to GitHub Releases
```

### Icon sources

| Output | Source | Use |
|---|---|---|
| `finder/icon.icns` | `icon.png` | macOS app icon + Finder Share menu |
| `finder/HTMLDrop.workflow/Contents/Resources/icon.icns` | `icon.png` | Quick Action icon |
| `pluginIcon.png` / `pluginIcon@2x.png` | `icon.png` | WebStorm plugin settings icon |
| `icons/icon16.png` | manual — do not overwrite | WebStorm context menu icon (light theme) |
| `icons/icon16_dark.png` | `icon16.png` negated | WebStorm context menu icon (dark theme, white logo) |

All source images live in `src/main/resources/icons/`. Run `npm run icon` to regenerate everything.

### Breakdown of `npm run release`
1. `npm version patch` — bumps `package.json` and syncs `build.gradle.kts`
2. `npm run build` — Gradle builds the WebStorm plugin zip
3. `npm run build:app` — swiftc builds `HTMLDrop.app`
4. `npm run package:dmg` — calls `scripts/package-dmg.sh`:
   - Runs `pkgbuild` → `build/HTMLDrop-vX.Y.Z.pkg`
   - Generates the DMG background with `scripts/generate-dmg-bg.swift`
   - Assembles the DMG, applies Finder window layout via AppleScript
   - Converts to compressed read-only UDZO DMG
5. `gh release create` — uploads `build/HTMLDrop-vX.Y.Z.dmg` to GitHub

---

## Upload API — pagedrop.io

**Endpoint:** `POST https://pagedrop.io/api/upload`  
**Auth:** none  
**Body:** `application/json` — `{"html": "<escaped html>", "ttl": "3d"}`  
**Response:** JSON with a `url` (or `link` / `page_url`) field  

Both the Swift and Kotlin sides share the same retry logic: on HTTP 429, wait 5 s → 15 s → 45 s then fail.

---

## Encryption (password-protected pages)

Both the plugin and the Swift CLI use identical crypto:

- **Key derivation:** PBKDF2-HMAC-SHA256, 100 000 iterations, 256-bit key, random 16-byte salt
- **Encryption:** AES-256-GCM, random 12-byte IV (nonce)
- **Output:** Self-contained HTML page — ciphertext embedded as base64, decrypted in-browser via the [Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto)
- The unlock page (`wrapperHtml`) is defined in both `HTMLDropCore.swift` and `ShareOnHTMLDropAction.kt` and must stay in sync

---

## WebStorm plugin

**Language:** Kotlin · **Build:** Gradle + `org.jetbrains.intellij.platform` v2.x · **JVM:** 21 · **Target:** WebStorm 2024.3 (build 243)

### Action flow
1. User right-clicks an `.html` file → **Share on HTML Drop**
2. `PasswordDialog` appears — enter a password or leave empty → Share
3. Background `Task.Backgroundable`:
   - Encrypts (if password given) or passes HTML through as-is
   - POSTs to pagedrop.io
   - Copies URL to clipboard
   - Shows balloon notification with **Open in Browser** action

### Key files
| File | Purpose |
|---|---|
| `ShareOnHTMLDropAction.kt` | Context menu action, upload, encrypt, notify |
| `PasswordDialog.kt` | Password prompt (`JPasswordField`) |
| `plugin.xml` | Plugin descriptor — id `com.pbonger.html-drop`, action registration |
| `pluginIcon.png` / `pluginIcon@2x.png` | Plugin icon in WebStorm settings (40 × 40) — from `icon.png` |
| `icons/icon16.png` | Context menu icon (16 × 16) — from `icon_black.png` |

### Known build quirks
- `instrumentCode` and `buildSearchableOptions` are **disabled** — `java-compiler-ant-tasks` for build 243 is not in JetBrains repos
- `compileOnly(kotlin("stdlib"))` prevents stdlib conflicts with the IntelliJ platform
- Gradle wrapper targets 8.8; system Gradle is only used once to generate the wrapper

---

## macOS Share Extension (`HTMLDrop.app`)

**Built with:** `swiftc` directly (no Xcode project) via `finder/build-app.sh`  
**Signed with:** ad-hoc (`codesign --sign -`), **not** notarised  
**Bundle IDs:** `com.pbonger.html-drop-app` (host) / `com.pbonger.html-drop-app.extension` (appex)  
**Min macOS:** 12.0

### Architecture
```
HTMLDrop.app/
  Contents/
    MacOS/HTMLDrop          ← stub host app (App/main.swift) — quits immediately
    PlugIns/
      HTMLDropExtension.appex/
        Contents/
          MacOS/HTMLDropExtension   ← extension binary
          Resources/AppIcon.icns
```

The extension binary is linked with `-Xlinker -e -Xlinker _NSExtensionMain` and compiled with `-parse-as-library` — no `main.swift` needed in the Extension folder.

### Extension entitlements (sandboxed)
- `com.apple.security.app-sandbox` ✓
- `com.apple.security.network.client` ✓ (upload to pagedrop.io)
- `com.apple.security.files.user-selected.read-only` ✓ (read the .html file)

### `ShareViewController.swift` flow
1. `beginRequest(with:)` — detects `public.html` vs `public.file-url` attachment
2. `loadViaFileRepresentation` — used when `public.html` type is present; loads a sandboxed temp copy and resolves the display filename via `public.file-url`; OR `loadViaFileURL` fallback when only `public.file-url` is available
3. `showShareDialog` — NSAlert with Share / Add Password… / Cancel
4. `showPasswordDialog` — NSAlert + NSSecureTextField
5. `upload(html:password:context:)` — encrypt if needed → `htmlDropUpload()` → copy URL → `showSuccess`
6. `showSuccess` — NSAlert with **Open in Browser** / OK

### Updating the app after code changes
```bash
npm run update:app
# equivalent to:
npm run build:app
sudo rm -rf /Applications/HTMLDrop.app
sudo cp -r finder/HTMLDrop.app /Applications/
sudo xattr -cr /Applications/HTMLDrop.app      # strip quarantine
pkill -f HTMLDropExtension 2>/dev/null || true
open /Applications/HTMLDrop.app
sleep 2
pluginkit -e use -i com.pbonger.html-drop-app.extension
```

---

## `.pkg` installer

`pkgbuild` bundles:
- `HTMLDrop.app` → `/Applications/`
- `html-drop-plugin.zip` → `/tmp/html-drop-install/` (picked up by `postinstall`)

`postinstall` (runs as root):
1. Strips quarantine from `HTMLDrop.app`
2. Kills any stale extension process, opens the app as the real user, calls `pluginkit -e use`
3. Finds all installed WebStorm versions via `~/Library/Application Support/JetBrains/WebStorm*/plugins` and unzips the plugin into each
4. Shows an osascript alert if the plugin was installed

---

## DMG layout

Window: 560 × 300 px, dark background generated by `scripts/generate-dmg-bg.swift`  
Contents: `HTML Drop.pkg` icon at position (415, 148)

Background image shows 5 install steps:
1. Double-click `HTML Drop.pkg`
2. Click **OK** on the warning dialog
3. Open **System Settings → Privacy & Security**
4. Scroll down, click **Open Anyway**
5. Follow the installer steps

> **Why the extra steps?** The `.app` and `.pkg` are ad-hoc signed only, not notarised. macOS Gatekeeper quarantines them. The `postinstall` script strips quarantine from the installed `.app`, but the `.pkg` itself still needs the user to approve it in System Settings once. There is no "right-click → Open Anyway" for `.pkg` files on macOS Ventura+.

---

## Security

- No credentials in this repo — pagedrop.io requires no auth
- Passwords entered by the user are never transmitted — only the encrypted ciphertext is uploaded

---

## Gitignore (key entries)

```
finder/.build/          # Swift SPM build artefacts
finder/.build-app/      # swiftc intermediate objects
finder/HTMLDrop.app/    # built app (generated)
finder/icon.icns        # generated from icon.png
build/                  # Gradle + pkg + DMG output
```
