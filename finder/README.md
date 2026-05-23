# Netlify Share — Finder Quick Action

Right-click any `.html` file in Finder → **Share on Netlify**.  
Uploads to Netlify, copies the URL to clipboard, and shows a macOS notification.

## Install

1. Download `NetlifyShare.workflow.zip` from the [latest release](https://github.com/pbonger/netlify-share-plugin/releases/latest).
2. Unzip — you'll get `NetlifyShare.workflow`.
3. Double-click `NetlifyShare.workflow` — Automator opens and asks to install it as a Quick Action.  
   Click **Install**.

> **Gatekeeper warning?** If macOS says the file is from an unidentified developer, right-click → Open instead of double-clicking, then click Open again in the dialog.

## Usage

Right-click any `.html` file in Finder → **Services → NetlifyShare** (or just **NetlifyShare** if it appears at the top level of the context menu).

On first use a browser window opens for Netlify login — after that the token is stored in the system keychain and you won't be asked again. The token is shared with the WebStorm plugin, so logging in once works in both.

After upload the URL is copied to your clipboard and a notification appears.

## Uninstall

Open **System Settings → Privacy & Security → Extensions → Finder Extensions** (or search for "Services" in System Settings), find NetlifyShare, and remove it.  
Or delete `~/Library/Services/NetlifyShare.workflow` directly.

## Build from source

```bash
git clone <this repo>
cd netlify-share-plugin
# Create finder/Sources/Credentials.swift (gitignored):
# let NETLIFY_CLIENT_ID     = "your_client_id"
# let NETLIFY_CLIENT_SECRET = "your_client_secret"
npm run build:finder    # compiles and copies binary into the workflow bundle
npm run package:finder  # zips to build/distributions/NetlifyShare.workflow.zip
```
