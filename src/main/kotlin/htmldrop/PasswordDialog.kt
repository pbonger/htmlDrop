package htmldrop

import com.intellij.openapi.ui.DialogWrapper
import java.awt.GridBagConstraints
import java.awt.GridBagLayout
import java.awt.Insets
import javax.swing.*

class PasswordDialog : DialogWrapper(true) {
    private val field = JPasswordField(24)

    init {
        title = "Share on HTML Drop"
        setOKButtonText("Share")
        init()
    }

    override fun createCenterPanel(): JComponent {
        val panel = JPanel(GridBagLayout())
        val gbc = GridBagConstraints().apply {
            insets = Insets(4, 0, 4, 0)
            fill = GridBagConstraints.HORIZONTAL
            gridwidth = GridBagConstraints.REMAINDER
        }
        panel.add(JLabel("Password protect this page? (leave empty to skip)"), gbc)
        panel.add(field, gbc)
        return panel
    }

    override fun getPreferredFocusedComponent() = field

    fun getPassword(): String? = if (showAndGet()) String(field.password) else null
}
