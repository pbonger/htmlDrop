# HTML Drop — Finder Quick Action

Right-click any `.html` file in Finder → **Share on HTML Drop**.  
Uploads to pagedrop.io, copies the URL to clipboard, and shows a macOS notification.

## Install

1. Download `HTMLDrop.workflow.zip` from the [latest release](https://github.com/pbonger/html-drop-plugin/releases/latest).
2. Unzip — you'll get `HTMLDrop.workflow`.
3. Double-click `HTMLDrop.workflow` — Automator opens and asks to install it as a Quick Action.  
   Click **Install**.

> **Gatekeeper warning?** If macOS says the file is from an unidentified developer, right-click → Open instead of double-clicking, then click Open again in the dialog.

## Usage

Right-click any `.html` file in Finder → **Services → Share on HTML Drop** (or just **Share on HTML Drop** if it appears at the top level of the context menu).

After upload the URL is copied to your clipboard and a notification appears.

## Uninstall

Open **System Settings → Privacy & Security → Extensions → Finder Extensions** (or search for "Services" in System Settings), find HTMLDrop, and remove it.  
Or delete `~/Library/Services/HTMLDrop.workflow` directly.

## Build from source

```bash
git clone <this repo>
cd html-drop-plugin
npm run build:finder    # compiles and copies binary into the workflow bundle
npm run package:finder  # zips to build/distributions/HTMLDrop.workflow.zip
```
