package netlifyshare

import com.intellij.notification.Notification
import com.intellij.notification.NotificationType
import com.intellij.notification.Notifications
import com.intellij.openapi.actionSystem.ActionUpdateThread
import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.actionSystem.CommonDataKeys
import com.intellij.ide.BrowserUtil
import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.progress.ProgressIndicator
import com.intellij.openapi.progress.ProgressManager
import com.intellij.openapi.progress.Task
import com.intellij.openapi.project.Project
import java.awt.Toolkit
import java.awt.datatransfer.StringSelection
import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.security.SecureRandom
import javax.crypto.spec.PBEKeySpec
import java.util.Base64
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class ShareOnNetlifyAction : AnAction() {

    override fun getActionUpdateThread(): ActionUpdateThread = ActionUpdateThread.BGT

    override fun update(e: AnActionEvent) {
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE)
        e.presentation.isEnabledAndVisible = file?.extension?.lowercase() == "html"
    }

    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE) ?: return

        val password = PasswordDialog().getPassword() ?: return

        ProgressManager.getInstance().run(object : Task.Backgroundable(project, "Sharing on Netlify…", false) {
            override fun run(indicator: ProgressIndicator) {
                runCatching {
                    val token = NetlifyAuthManager.getToken() ?: run {
                        indicator.text = "Logging in to Netlify…"
                        NetlifyAuthManager.login()
                    } ?: error("Login cancelled")

                    val html = file.contentsToByteArray().toString(Charsets.UTF_8)
                    val content = if (password.isNotEmpty()) encrypt(html, password) else wrapPlain(html)
                    val zipBytes = zip("index.html", content.toByteArray(Charsets.UTF_8))
                    indicator.text = "Uploading to Netlify…"
                    val url = upload(zipBytes, token, indicator)
                    ApplicationManager.getApplication().invokeLater { copyToClipboard(url) }
                    val msg = if (password.isNotEmpty()) "URL copied to clipboard (password protected)" else "URL copied to clipboard"
                    notifyWithLink(project, "Shared on Netlify", msg, url, NotificationType.INFORMATION)
                }.onFailure { ex ->
                    notify(project, "Netlify Share Failed", ex.message ?: "Unknown error", NotificationType.ERROR)
                }
            }
        })
    }

    private fun wrapPlain(html: String): String {
        val b64 = Base64.getEncoder().encodeToString(html.toByteArray(Charsets.UTF_8))
        return """<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body><script>
(function(){var b=atob('$b64');var a=new Uint8Array(b.length);for(var i=0;i<b.length;i++)a[i]=b.charCodeAt(i);var h=new TextDecoder().decode(a);document.open();document.write(h);document.close();})();
</script></body></html>"""
    }

    private fun encrypt(html: String, password: String): String {
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val iv = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val keyBytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
            .generateSecret(PBEKeySpec(password.toCharArray(), salt, 100_000, 256)).encoded
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(keyBytes, "AES"), GCMParameterSpec(128, iv))
        val ct = cipher.doFinal(html.toByteArray(Charsets.UTF_8))
        val enc = Base64.getEncoder()
        return wrapperHtml(enc.encodeToString(salt), enc.encodeToString(iv), enc.encodeToString(ct))
    }

    private fun wrapperHtml(salt: String, iv: String, ct: String) = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Protected Page</title>
<style>
  body{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#f5f5f5}
  .box{background:#fff;padding:2rem;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.12);width:320px}
  h2{margin:0 0 1rem;font-size:1.1rem}
  input{width:100%;padding:.5rem;border:1px solid #ddd;border-radius:4px;font-size:1rem;box-sizing:border-box}
  button{margin-top:.75rem;width:100%;padding:.5rem;background:#00ad9f;color:#fff;border:none;border-radius:4px;font-size:1rem;cursor:pointer}
  button:hover{background:#009688}
  .err{color:#c0392b;font-size:.85rem;margin-top:.5rem;display:none}
</style>
</head>
<body>
<div class="box">
  <h2>🔒 Password protected</h2>
  <input type="password" id="p" placeholder="Enter password" autofocus>
  <button onclick="go()">Unlock</button>
  <div class="err" id="e">Wrong password — try again.</div>
</div>
<script>
const S='$salt',I='$iv',C='$ct';
const b=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
async function go(){
  try{
    const km=await crypto.subtle.importKey('raw',new TextEncoder().encode(document.getElementById('p').value),'PBKDF2',false,['deriveKey']);
    const k=await crypto.subtle.deriveKey({name:'PBKDF2',salt:b(S),iterations:100000,hash:'SHA-256'},km,{name:'AES-GCM',length:256},false,['decrypt']);
    const plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:b(I)},k,b(C));
    document.open();document.write(new TextDecoder().decode(plain));document.close();
  }catch{document.getElementById('e').style.display='block';}
}
document.getElementById('p').addEventListener('keydown',e=>{if(e.key==='Enter')go();});
</script>
</body>
</html>"""

    private fun zip(fileName: String, content: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zos ->
            zos.putNextEntry(ZipEntry(fileName))
            zos.write(content)
            zos.closeEntry()
            zos.putNextEntry(ZipEntry("_headers"))
            zos.write("/*\n  Content-Type: text/html; charset=utf-8\n".toByteArray(Charsets.UTF_8))
            zos.closeEntry()
        }
        return out.toByteArray()
    }

    private fun upload(zipBytes: ByteArray, token: String, indicator: ProgressIndicator): String {
        val client = HttpClient.newHttpClient()
        val res = client.send(
            HttpRequest.newBuilder()
                .uri(URI.create("https://api.netlify.com/api/v1/sites"))
                .header("Content-Type", "application/zip")
                .header("Authorization", "Bearer $token")
                .POST(HttpRequest.BodyPublishers.ofByteArray(zipBytes))
                .build(),
            HttpResponse.BodyHandlers.ofString()
        )
        check(res.statusCode() in 200..299) { "Netlify API ${res.statusCode()}: ${res.body()}" }

        val body = res.body()
        val url = Regex(""""ssl_url"\s*:\s*"([^"]+)"""").find(body)?.groupValues?.get(1)
            ?: Regex(""""url"\s*:\s*"([^"]+)"""").find(body)?.groupValues?.get(1)
            ?: error("No URL in response: $body")

        // Deploy URLs have a deploy-ID prefix (e.g. https://abc123--site.netlify.app) and
        // serve files as plain text before the deploy finishes. Strip the prefix to get the
        // canonical site URL (https://site.netlify.app) which always renders HTML correctly.
        val deployId = Regex("""https?://([0-9a-f]+)--""").find(url)?.groupValues?.get(1)
        val siteUrl = if (deployId != null) url.replace("$deployId--", "") else url

        if (deployId != null) {
            indicator.text = "Waiting for deploy to go live…"
            for (i in 1..30) {
                Thread.sleep(2_000)
                val poll = client.send(
                    HttpRequest.newBuilder()
                        .uri(URI.create("https://api.netlify.com/api/v1/deploys/$deployId"))
                        .header("Authorization", "Bearer $token")
                        .GET().build(),
                    HttpResponse.BodyHandlers.ofString()
                )
                if (Regex(""""state"\s*:\s*"ready"""").containsMatchIn(poll.body())) return siteUrl
            }
        }
        return siteUrl
    }

    private fun copyToClipboard(text: String) {
        StringSelection(text).let { Toolkit.getDefaultToolkit().systemClipboard.setContents(it, it) }
    }

    private fun notifyWithLink(project: Project?, title: String, content: String, url: String, type: NotificationType) {
        val n = Notification("Netlify Share", title, content, type)
        n.addAction(object : AnAction("Open in Browser") {
            override fun actionPerformed(e: AnActionEvent) { BrowserUtil.browse(java.net.URI(url)) }
        })
        Notifications.Bus.notify(n, project)
    }

    private fun notify(project: Project?, title: String, content: String, type: NotificationType) {
        Notifications.Bus.notify(Notification("Netlify Share", title, content, type), project)
    }
}
