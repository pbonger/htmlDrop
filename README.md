# Netlify Share — WebStorm Plugin

Right-click any `.html` file in WebStorm → **Share on Netlify**.  
Zips the file, uploads to Netlify, copies the URL to clipboard, and shows a notification.  
Optionally password-protects the page with client-side AES-256 encryption.

## Setup

Requires Node.js and Homebrew. Java 21+ is required — `npm install` handles it automatically.

```bash
git clone <this repo>
cd netlify-share-plugin
npm install   # installs Gradle + JDK if missing, generates the Gradle wrapper
```

### Credentials

The Netlify OAuth credentials are not in the repo. Create `src/main/kotlin/netlifyshare/Credentials.kt` (gitignored):

```kotlin
package netlifyshare

internal const val NETLIFY_CLIENT_ID     = "your_client_id"
internal const val NETLIFY_CLIENT_SECRET = "your_client_secret"
```

Get these from **app.netlify.com → User Settings → Applications → OAuth Apps → New OAuth app**.  
Set the redirect URL to `http://localhost`.

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

Right-click any `.html` file → **Share on Netlify**. On first use, a browser window opens for Netlify login — after that the token is stored in the system keychain and login is never asked again.

## Update

After pulling changes:

```bash
npm run build
```

Then reinstall the new `.zip` via Settings → Plugins → gear → **Install Plugin from Disk**.  
WebStorm will prompt to replace the existing version.
