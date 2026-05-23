# Netlify Share — Installation

Right-click any `.html` file to share it on Netlify. Works in WebStorm and macOS Finder.  
Authenticate once — both tools share the same login.

---

## WebStorm Plugin

1. Open WebStorm → **Settings → Plugins**
2. Gear icon → **Install Plugin from Disk**
3. Select `netlify-share-plugin-*.zip` from this folder
4. Restart WebStorm

Right-click any `.html` file → **Share on Netlify**.

---

## Finder Quick Action (macOS)

1. Double-click `NetlifyShare.workflow`
2. Automator asks to install it — click **Install**

Right-click any `.html` file in Finder → **Services → NetlifyShare**.

> **Gatekeeper warning?** Right-click `NetlifyShare.workflow` → **Open**, then click **Open** again in the dialog.

---

## First use

A browser window opens for Netlify login. After that the token is stored in the system keychain and you won't be asked again.
