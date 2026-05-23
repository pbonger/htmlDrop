package htmldrop

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
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.security.SecureRandom
import javax.crypto.spec.PBEKeySpec
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class ShareOnHTMLDropAction : AnAction() {

    override fun getActionUpdateThread(): ActionUpdateThread = ActionUpdateThread.BGT

    override fun update(e: AnActionEvent) {
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE)
        e.presentation.isEnabledAndVisible = file?.extension?.lowercase() == "html"
    }

    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE) ?: return

        val password = PasswordDialog(file.name).getPassword() ?: return

        ProgressManager.getInstance().run(object : Task.Backgroundable(project, "Sharing on HTML Drop…", false) {
            override fun run(indicator: ProgressIndicator) {
                runCatching {
                    val html = file.contentsToByteArray().toString(Charsets.UTF_8)
                    val content = if (password.isNotEmpty()) encrypt(html, password) else html
                    indicator.text = "Uploading to HTML Drop…"
                    val url = upload(content)
                    ApplicationManager.getApplication().invokeLater { copyToClipboard(url) }
                    val msg = if (password.isNotEmpty()) "URL copied to clipboard (password protected)" else "URL copied to clipboard"
                    notifyWithLink(project, "Shared on HTML Drop", msg, url, NotificationType.INFORMATION)
                }.onFailure { ex ->
                    notify(project, "HTML Drop Failed", ex.message ?: "Unknown error", NotificationType.ERROR)
                }
            }
        })
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
<title>Protected Page · HTML Drop</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;min-height:100vh;display:flex;flex-direction:column;justify-content:center;align-items:center;background:linear-gradient(135deg,#0d0d1a 0%,#1a1040 50%,#0d1a2e 100%);padding:1.5rem}
.card{background:#fff;border-radius:24px;padding:2.5rem 2rem 2rem;width:100%;max-width:380px;box-shadow:0 32px 80px rgba(0,0,0,.6);text-align:center}
.icon{width:80px;height:80px;margin:0 auto .75rem;display:block}
.brand-name{font-size:1.4rem;font-weight:700;background:linear-gradient(90deg,#5b6af0,#9b5cf6);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;margin-bottom:1.5rem}
.title{font-size:1.05rem;font-weight:700;color:#111;margin-bottom:.4rem}
.sub{font-size:.875rem;color:#888;margin-bottom:1.5rem}
input[type=password]{width:100%;padding:.75rem 1rem;border:1.5px solid #e5e7eb;border-radius:12px;font-size:1rem;outline:none;background:#f9fafb;transition:border-color .15s,background .15s}
input[type=password]:focus{border-color:#9b5cf6;background:#fff}
button{margin-top:.75rem;width:100%;padding:.8rem;background:linear-gradient(90deg,#5b7cf6,#9b5cf6);color:#fff;border:none;border-radius:12px;font-size:1rem;font-weight:600;cursor:pointer;transition:opacity .15s}
button:hover{opacity:.88}
.err{color:#dc2626;font-size:.82rem;margin-top:.6rem;display:none}
footer{margin-top:1.75rem;font-size:.75rem;color:rgba(255,255,255,.35);text-align:center}
footer a{color:rgba(255,255,255,.5);text-decoration:none}
footer a:hover{color:rgba(255,255,255,.8)}
</style>
</head>
<body>
<div class="card">
  <img class="icon" src="data:image/png;base64,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">
  <div class="brand-name">HTML Drop</div>
  <div class="title">This page is password protected</div>
  <div class="sub">Enter the password to unlock the content.</div>
  <input type="password" id="p" placeholder="Password" autofocus>
  <button onclick="go()">Unlock</button>
  <div class="err" id="e">Wrong password — try again.</div>
</div>
<footer>Shared via <a href="https://pagedrop.io" target="_blank">pagedrop.io</a></footer>
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

    private fun upload(html: String): String {
        val json = """{"html":${jsonString(html)},"ttl":"3d"}"""
        val client = HttpClient.newHttpClient()
        val request = HttpRequest.newBuilder()
            .uri(URI.create("https://pagedrop.io/api/upload"))
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(json))
            .build()
        val retryDelays = listOf(5_000L, 15_000L, 45_000L)
        for ((attempt, delay) in (listOf(0L) + retryDelays).withIndex()) {
            if (delay > 0) Thread.sleep(delay)
            val res = client.send(request, HttpResponse.BodyHandlers.ofString())
            if (res.statusCode() == 429) {
                if (attempt < retryDelays.size) continue
                error("Rate limited by HTML Drop — please try again later")
            }
            check(res.statusCode() in 200..299) { "HTML Drop API ${res.statusCode()}: ${res.body()}" }
            val body = res.body()
            return Regex(""""url"\s*:\s*"([^"]+)"""").find(body)?.groupValues?.get(1)
                ?: Regex(""""link"\s*:\s*"([^"]+)"""").find(body)?.groupValues?.get(1)
                ?: Regex(""""page_url"\s*:\s*"([^"]+)"""").find(body)?.groupValues?.get(1)
                ?: error("No URL in response: $body")
        }
        error("Upload failed after retries")
    }

    private fun jsonString(s: String): String {
        val sb = StringBuilder("\"")
        for (ch in s) {
            when (ch) {
                '"'  -> sb.append("\\\"")
                '\\' -> sb.append("\\\\")
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                '\t' -> sb.append("\\t")
                else -> if (ch.code < 0x20) sb.append("\\u%04x".format(ch.code)) else sb.append(ch)
            }
        }
        return sb.append('"').toString()
    }

    private fun copyToClipboard(text: String) {
        StringSelection(text).let { Toolkit.getDefaultToolkit().systemClipboard.setContents(it, it) }
    }

    private fun notifyWithLink(project: Project?, title: String, content: String, url: String, type: NotificationType) {
        val n = Notification("HTML Drop", title, content, type)
        n.addAction(object : AnAction("Open in Browser") {
            override fun actionPerformed(e: AnActionEvent) { BrowserUtil.browse(java.net.URI(url)) }
        })
        Notifications.Bus.notify(n, project)
    }

    private fun notify(project: Project?, title: String, content: String, type: NotificationType) {
        Notifications.Bus.notify(Notification("HTML Drop", title, content, type), project)
    }
}
