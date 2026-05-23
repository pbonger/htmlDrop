package netlifyshare

import com.intellij.notification.Notification
import com.intellij.notification.NotificationType
import com.intellij.notification.Notifications
import com.intellij.openapi.actionSystem.ActionUpdateThread
import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.actionSystem.CommonDataKeys
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
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class ShareOnNetlifyAction : AnAction() {

    override fun getActionUpdateThread(): ActionUpdateThread = ActionUpdateThread.BGT

    override fun update(e: AnActionEvent) {
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE)
        e.presentation.isEnabledAndVisible = file?.extension?.lowercase() == "html"
    }

    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE) ?: return

        ProgressManager.getInstance().run(object : Task.Backgroundable(project, "Sharing on Netlify…", false) {
            override fun run(indicator: ProgressIndicator) {
                runCatching {
                    val zipBytes = zip(file.name, file.contentsToByteArray())
                    val url = upload(zipBytes)
                    ApplicationManager.getApplication().invokeLater { copyToClipboard(url) }
                    notify(project, "Shared on Netlify", url, NotificationType.INFORMATION)
                }.onFailure { ex ->
                    notify(project, "Netlify Share Failed", ex.message ?: "Unknown error", NotificationType.ERROR)
                }
            }
        })
    }

    private fun zip(fileName: String, content: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zos ->
            zos.putNextEntry(ZipEntry(fileName))
            zos.write(content)
            zos.closeEntry()
        }
        return out.toByteArray()
    }

    private fun upload(zipBytes: ByteArray): String {
        val client = HttpClient.newHttpClient()
        val request = HttpRequest.newBuilder()
            .uri(URI.create("https://api.netlify.com/api/v1/sites"))
            .header("Content-Type", "application/zip")
            .POST(HttpRequest.BodyPublishers.ofByteArray(zipBytes))
            .build()
        val response = client.send(request, HttpResponse.BodyHandlers.ofString())
        check(response.statusCode() in 200..299) {
            "Netlify API ${response.statusCode()}: ${response.body()}"
        }
        return Regex(""""url"\s*:\s*"([^"]+)"""")
            .find(response.body())
            ?.groupValues?.get(1)
            ?: error("No 'url' field in response: ${response.body()}")
    }

    private fun copyToClipboard(text: String) {
        StringSelection(text).let { Toolkit.getDefaultToolkit().systemClipboard.setContents(it, it) }
    }

    private fun notify(project: Project?, title: String, content: String, type: NotificationType) {
        Notifications.Bus.notify(Notification("Netlify Share", title, content, type), project)
    }
}
