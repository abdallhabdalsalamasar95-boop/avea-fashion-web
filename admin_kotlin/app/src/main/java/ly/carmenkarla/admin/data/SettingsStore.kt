package ly.carmenkarla.admin.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore("admin_settings")

class SettingsStore(private val context: Context) {

    private val baseUrlKey = stringPreferencesKey("base_url")
    private val tokenKey = stringPreferencesKey("api_token")
    private val notifiedWithdrawalIdsKey = stringPreferencesKey("notified_withdrawal_ids")

    val baseUrl = context.dataStore.data.map { it[baseUrlKey] ?: DEFAULT_BASE_URL }
    val token = context.dataStore.data.map { it[tokenKey] ?: "" }

    suspend fun currentBaseUrl(): String = baseUrl.first()

    suspend fun currentToken(): String = token.first()

    suspend fun save(baseUrl: String, token: String) {
        context.dataStore.edit {
            it[baseUrlKey] = normalizeBaseUrl(baseUrl)
            it[tokenKey] = token.trim()
        }
    }

    suspend fun clearToken() {
        context.dataStore.edit { it[tokenKey] = "" }
    }

    /** IDs of pending withdrawal requests already alerted, so the same request isn't notified twice. */
    suspend fun notifiedWithdrawalIds(): Set<String> =
        context.dataStore.data.map { it[notifiedWithdrawalIdsKey] ?: "" }.first()
            .split(",").filter { it.isNotBlank() }.toSet()

    suspend fun addNotifiedWithdrawalIds(ids: Set<String>) {
        if (ids.isEmpty()) return
        context.dataStore.edit {
            val current = (it[notifiedWithdrawalIdsKey] ?: "").split(",").filter { id -> id.isNotBlank() }.toSet()
            it[notifiedWithdrawalIdsKey] = (current + ids).toList().takeLast(500).joinToString(",")
        }
    }

    companion object {
        const val DEFAULT_BASE_URL = "https://carmenkarla-backend.onrender.com/"

        fun normalizeBaseUrl(value: String): String {
            val trimmed = value.trim().ifEmpty { DEFAULT_BASE_URL }
            val withScheme = if (trimmed.startsWith("http")) trimmed else "https://$trimmed"
            return if (withScheme.endsWith("/")) withScheme else "$withScheme/"
        }
    }
}
