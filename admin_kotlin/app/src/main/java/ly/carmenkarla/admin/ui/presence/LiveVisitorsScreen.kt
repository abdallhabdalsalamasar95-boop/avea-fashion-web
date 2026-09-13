package ly.carmenkarla.admin.ui.presence

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.PresenceResponse
import ly.carmenkarla.admin.data.PresenceVisitor

private const val REFRESH_MS = 10_000L

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveVisitorsScreen(onBack: () -> Unit) {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()
    var presence by remember { mutableStateOf<PresenceResponse?>(null) }
    var error by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var reload by remember { mutableIntStateOf(0) }

    LaunchedEffect(reload) {
        while (true) {
            runCatching { repository.presence() }
                .onSuccess {
                    presence = it
                    error = ""
                }
                .onFailure { error = it.message ?: "تعذر تحميل الزوار" }
            delay(REFRESH_MS)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("يتصفحون الآن") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "رجوع") }
                },
                actions = {
                    IconButton(onClick = { reload++ }) { Icon(Icons.Default.Refresh, "تحديث") }
                },
            )
        },
    ) { padding ->
        val data = presence
        LazyColumn(
            Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Card(
                    Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer,
                    ),
                ) {
                    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Counter(data?.online?.toString() ?: "—", "الآن", Modifier.weight(1f))
                        Counter(data?.onlineApp?.toString() ?: "—", "التطبيق", Modifier.weight(1f))
                        Counter(data?.onlineWeb?.toString() ?: "—", "الموقع", Modifier.weight(1f))
                        Counter(data?.lastHour?.toString() ?: "—", "آخر ساعة", Modifier.weight(1f))
                    }
                }
            }

            item {
                Card(Modifier.fillMaxWidth()) {
                    Column {
                        SettingRow(
                            title = "تتبع الزوار",
                            subtitle = if (data?.enabled != false) {
                                "مفعّل — يستقبل الخادم نبضة كل 30 ثانية من كل زائرة"
                            } else {
                                "موقوف — لا يرسل التطبيق ولا الموقع أي طلبات، ولا تُحتسب على الفاتورة"
                            },
                            checked = data?.enabled != false,
                            enabled = data != null && !busy,
                        ) { next ->
                            busy = true
                            scope.launch {
                                runCatching {
                                    repository.updatePresenceSettings(next, data?.showNames != false)
                                }
                                    .onSuccess { presence = data?.copy(enabled = it.enabled, showNames = it.showNames) }
                                    .onFailure { error = it.message ?: "تعذر حفظ الإعداد" }
                                busy = false
                                reload++
                            }
                        }
                        SettingRow(
                            title = "إظهار الأسماء",
                            subtitle = "عند الإيقاف يظهر العدد فقط بدون أي بيانات للزائرات",
                            checked = data?.showNames != false,
                            enabled = data?.enabled != false && !busy,
                        ) { next ->
                            busy = true
                            scope.launch {
                                runCatching {
                                    repository.updatePresenceSettings(data?.enabled != false, next)
                                }
                                    .onSuccess { presence = data?.copy(enabled = it.enabled, showNames = it.showNames) }
                                    .onFailure { error = it.message ?: "تعذر حفظ الإعداد" }
                                busy = false
                                reload++
                            }
                        }
                    }
                }
            }

            if (error.isNotEmpty()) {
                item {
                    Text(error, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.error)
                }
            }

            when {
                data == null -> item { Hint("جارٍ التحميل...") }
                !data.enabled -> item { Hint("التتبع موقوف حاليًا. فعّليه من الأعلى لرؤية الزائرات.") }
                !data.showNames -> item { Hint("إظهار الأسماء موقوف. العدد فقط معروض بالأعلى.") }
                data.visitors.isEmpty() -> item { Hint("لا توجد زائرة على المتجر في هذه اللحظة.") }
                else -> itemsIndexed(data.visitors) { index, visitor ->
                    VisitorRow(index + 1, visitor)
                }
            }
        }
    }
}

@Composable
private fun Counter(value: String, label: String, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            value,
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onPrimaryContainer,
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onPrimaryContainer,
        )
    }
}

@Composable
private fun SettingRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    enabled: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(
                subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.width(10.dp))
        Switch(checked = checked, onCheckedChange = onChange, enabled = enabled)
    }
}

@Composable
private fun Hint(text: String) {
    Text(
        text,
        Modifier
            .fillMaxWidth()
            .padding(vertical = 26.dp),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
    )
}

@Composable
private fun VisitorRow(position: Int, visitor: PresenceVisitor) {
    Card(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(
                        if (visitor.signedIn) MaterialTheme.colorScheme.primaryContainer
                        else MaterialTheme.colorScheme.surfaceVariant,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    visitor.name.take(1).ifBlank { "$position" },
                    style = MaterialTheme.typography.titleSmall,
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    visitor.name.ifBlank { "زائرة غير مسجّلة" },
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = if (visitor.signedIn) FontWeight.Bold else FontWeight.Normal,
                )
                val meta = listOfNotNull(
                    if (visitor.platform == "web") "الموقع" else "التطبيق",
                    visitor.city.takeIf { it.isNotBlank() },
                    visitor.screen.takeIf { it.isNotBlank() },
                ).joinToString(" · ")
                Text(
                    meta,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .size(7.dp)
                            .clip(CircleShape)
                            .background(if (visitor.secondsAgo <= 45) Color(0xFF2E9E5B) else Color(0xFFE0A31E)),
                    )
                    Spacer(Modifier.width(5.dp))
                    Text(duration(visitor.secondsHere), style = MaterialTheme.typography.labelMedium)
                }
                Text(
                    "آخر نشاط ${duration(visitor.secondsAgo)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

private fun duration(seconds: Int): String = when {
    seconds < 60 -> "$seconds ثانية"
    seconds < 3600 -> "${seconds / 60} دقيقة"
    else -> "${seconds / 3600} ساعة"
}
