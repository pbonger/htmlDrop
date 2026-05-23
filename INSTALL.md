# HTML Drop — Installation

Right-click any `.html` file to instantly share it. Works in **WebStorm** and **macOS Finder**.

---

## 1. WebStorm Plugin

1. Open WebStorm → **Settings → Plugins**
2. Click the ⚙️ gear icon → **Install Plugin from Disk…**
3. Select `html-drop-plugin-*.zip` from this folder
4. Restart WebStorm

Right-click any `.html` file → **Share on HTML Drop**.

---

## 2. Finder (macOS Share menu)

1. Drag **`HTMLDrop.app`** from this folder to your **Applications** folder
2. Open **`HTMLDrop.app`** once — it registers itself and quits immediately
3. Right-click any `.html` file in Finder → **Share** → **HTML Drop**

> **Doesn't appear in the Share menu?**  
> Run this once in Terminal:  
> `pluginkit -a /Applications/HTMLDrop.app/Contents/PlugIns/HTMLDropExtension.appex`  
> Then log out and back in.

> **Gatekeeper warning?**  
> Right-click `HTMLDrop.app` → **Open**, then click **Open** again.
