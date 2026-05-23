# HTML Drop

Right-click any `.html` file → **Share on HTML Drop**.  
Uploads to [pagedrop.io](https://pagedrop.io), copies the URL to clipboard, and shows a notification.  
Optionally password-protects the page with client-side AES-256 encryption.

Available as a **WebStorm plugin** and a **macOS Finder Quick Action**.

## Finder (macOS Share menu)

1. Download `html-drop-v*.zip` from the [latest release](../../releases/latest) and unzip it.
2. Double-click **`HTMLDrop.pkg`** and click through the installer.
3. If macOS blocks it: click Done to dismiss, then go to **System Settings → Privacy & Security → Open Anyway** next to HTMLDrop.pkg.
4. Right-click any `.html` file in Finder → **Share** → **HTML Drop**.

> The installer handles everything — no Terminal needed.

See [finder/README.md](finder/README.md) for build-from-source instructions.

---

## WebStorm Plugin

### Setup

Requires Node.js and Homebrew. Java 21+ is required — `npm install` handles it automatically.

```bash
git clone <this repo>
cd html-drop-plugin
npm install   # installs Gradle + JDK if missing, generates the Gradle wrapper
```

### Build

```bash
npm run build
```

Output: `build/distributions/html-drop-plugin-1.0.9.zip`

### Install in WebStorm

1. WebStorm → Settings → Plugins
2. Click the gear icon → **Install Plugin from Disk**
3. Select the `.zip` from `build/distributions/`
4. Restart WebStorm

Right-click any `.html` file → **Share on HTML Drop**.

### Update

After pulling changes:

```bash
npm run build
```

Then reinstall the new `.zip` via Settings → Plugins → gear → **Install Plugin from Disk**.  
WebStorm will prompt to replace the existing version.

---

## Release

```bash
npm run release
```

Bumps the patch version, builds the WebStorm plugin and Finder workflow (with binary embedded), and creates a GitHub release with both zips attached.
