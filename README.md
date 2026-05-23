# Netlify Share — WebStorm Plugin

Right-click any `.html` file in WebStorm → **Share on Netlify**.  
Zips the file, uploads to Netlify Drop, copies the URL to clipboard, and shows a notification.

## Setup

Requires Node.js and Homebrew. Java 17+ must be installed (WebStorm ships with one — point `JAVA_HOME` at it or install separately via `brew install openjdk@17`).

```bash
git clone <this repo>
cd netlify-share-plugin
npm install   # installs Gradle if missing, then generates the Gradle wrapper
```

## Build

```bash
npm run build
```

Output: `build/distributions/netlify-share-plugin-1.0.0.zip`

## Install in WebStorm

1. WebStorm → Settings → Plugins
2. Click the gear icon → **Install Plugin from Disk**
3. Select the `.zip` from `build/distributions/`
4. Restart WebStorm

Right-click any `.html` file in the Project panel or editor tab to see **Share on Netlify**.

## Update

After pulling changes:

```bash
npm run build
```

Then reinstall the new `.zip` via Settings → Plugins → gear → **Install Plugin from Disk**.  
WebStorm will prompt to replace the existing version.
