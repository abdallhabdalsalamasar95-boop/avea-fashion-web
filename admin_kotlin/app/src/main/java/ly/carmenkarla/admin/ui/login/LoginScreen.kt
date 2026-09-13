package ly.carmenkarla.admin.ui.login

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.SettingsStore
import ly.carmenkarla.admin.ui.LabeledField

@Composable
fun LoginScreen(onSignedIn: () -> Unit) {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()

    var baseUrl by remember { mutableStateOf(SettingsStore.DEFAULT_BASE_URL) }
    var token by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("كارمن كارلا", style = MaterialTheme.typography.headlineMedium)
        Text(
            "لوحة تحكم المتجر",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(28.dp))

        LabeledField("عنوان الخادم", baseUrl, { baseUrl = it })
        Spacer(Modifier.height(12.dp))
        LabeledField("رمز الدخول (API Token)", token, { token = it })

        if (error.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            Text(
                error,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {
                if (token.isBlank()) {
                    error = "أدخل رمز الدخول"
                    return@Button
                }
                busy = true
                error = ""
                scope.launch {
                    repository.settings.save(baseUrl, token)
                    repository.invalidate()
                    runCatching { repository.dashboard() }
                        .onSuccess { onSignedIn() }
                        .onFailure {
                            repository.settings.clearToken()
                            error = "تعذر الاتصال أو الرمز غير صحيح"
                        }
                    busy = false
                }
            },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (busy) CircularProgressIndicator(Modifier.height(18.dp)) else Text("دخول")
        }
    }
}
