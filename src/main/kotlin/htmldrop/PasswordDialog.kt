package htmldrop

import com.intellij.openapi.ui.DialogWrapper
import com.intellij.ui.components.JBLabel
import com.intellij.ui.components.JBPasswordField
import com.intellij.ui.dsl.builder.AlignX
import com.intellij.ui.dsl.builder.panel
import com.intellij.util.ui.JBUI
import javax.swing.JComponent

class PasswordDialog(private val filename: String) : DialogWrapper(true) {
    private val field = JBPasswordField().apply {
        emptyText.text = "Leave blank to share without a password"
        columns = 28
    }

    init {
        title = "Share on HTML Drop"
        setOKButtonText("Share")
        init()
    }

    override fun createCenterPanel(): JComponent = panel {
        row {
            val label = JBLabel(filename)
            label.foreground = JBUI.CurrentTheme.ContextHelp.FOREGROUND
            cell(label)
        }
        row("Password:") {
            cell(field).align(AlignX.FILL)
        }
        row {
            comment("Encrypted with AES-256 in the browser — the server never sees the password.")
        }
    }.apply {
        border = JBUI.Borders.empty(8, 4, 4, 4)
    }

    override fun getPreferredFocusedComponent() = field

    fun getPassword(): String? = if (showAndGet()) String(field.password) else null
}
