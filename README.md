# HTML Drop

Right-click any `.html` file → **Share on HTML Drop**.  
Uploads to [pagedrop.io](https://pagedrop.io), copies the URL to clipboard, and shows a notification.  
Optionally password-protects the page with client-side AES-256 encryption.

Available as a **WebStorm plugin** and a **macOS Finder Quick Action**.

## Finder Quick Action (macOS)

1. Download `HTMLDrop.workflow.zip` from the [latest release](../../releases/latest).
2. Unzip and double-click `HTMLDrop.workflow` — Automator installs it as a Quick Action.

Right-click any `.html` file in Finder → **Services → Share on HTML Drop**.

> Gatekeeper warning? Right-click → Open instead of double-clicking.

See [finder/README.md](finder/README.md) for full details and build-from-source instructions.

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
