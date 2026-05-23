package netlifyshare

import com.intellij.credentialStore.CredentialAttributes
import com.intellij.credentialStore.generateServiceName
import com.intellij.ide.BrowserUtil
import com.intellij.ide.passwordSafe.PasswordSafe
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.ServerSocket
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

object NetlifyAuthManager {

    private val CLIENT_ID     = NETLIFY_CLIENT_ID
    private val CLIENT_SECRET = NETLIFY_CLIENT_SECRET

    private fun credAttrs() = CredentialAttributes(generateServiceName("NetlifyShare", "access_token"))

    fun getToken(): String? = PasswordSafe.instance.getPassword(credAttrs())
    fun clearToken()        = PasswordSafe.instance.setPassword(credAttrs(), null)

    fun login(): String? {
        val port        = 34000
        val redirectUri = "http://localhost:$port"
        val authUrl     = "https://app.netlify.com/authorize" +
            "?client_id=${enc(CLIENT_ID)}" +
            "&redirect_uri=${enc(redirectUri)}" +
            "&response_type=code"

        val codeFuture = callbackServer(port)
        BrowserUtil.browse(URI(authUrl))

        val code  = codeFuture.get(5, TimeUnit.MINUTES) ?: return null
        val token = exchangeToken(code, redirectUri)    ?: return null
        PasswordSafe.instance.setPassword(credAttrs(), token)
        return token
    }

    private fun freePort(): Int = ServerSocket(0).use { it.localPort }

    private fun callbackServer(port: Int): CompletableFuture<String?> {
        val future = CompletableFuture<String?>()
        Thread {
            runCatching {
                ServerSocket(port).use { server ->
                    server.soTimeout = 300_000
                    val socket = server.accept()
                    val line   = BufferedReader(InputStreamReader(socket.getInputStream())).readLine() ?: ""
                    val code   = Regex("[?&]code=([^& ]+)").find(line)?.groupValues?.get(1)
                    val body   = if (code != null) "Authenticated — you can close this tab."
                                 else              "Authentication failed — please try again."
                    socket.getOutputStream()
                        .write("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<h2>$body</h2>".toByteArray())
                    socket.close()
                    future.complete(code)
                }
            }.onFailure { future.completeExceptionally(it) }
        }.apply { isDaemon = true; name = "netlify-oauth" }.start()
        return future
    }

    private fun exchangeToken(code: String, redirectUri: String): String? {
        val body = "grant_type=authorization_code" +
            "&code=${enc(code)}" +
            "&client_id=${enc(CLIENT_ID)}" +
            "&client_secret=${enc(CLIENT_SECRET)}" +
            "&redirect_uri=${enc(redirectUri)}"

        val res = HttpClient.newHttpClient().send(
            HttpRequest.newBuilder()
                .uri(URI.create("https://api.netlify.com/oauth/token"))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build(),
            HttpResponse.BodyHandlers.ofString()
        )
        if (res.statusCode() !in 200..299) return null
        return Regex(""""access_token"\s*:\s*"([^"]+)"""").find(res.body())?.groupValues?.get(1)
    }

    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8")
}
