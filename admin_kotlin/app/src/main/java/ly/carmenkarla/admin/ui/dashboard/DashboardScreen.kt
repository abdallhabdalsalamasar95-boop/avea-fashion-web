package ly.carmenkarla.admin.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.DashboardSummary
import ly.carmenkarla.admin.data.PresenceResponse
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox

private data class Stat(val label: String, val value: String)

@Composable
private fun DashboardHeroCard(data: DashboardSummary, presence: PresenceResponse?) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.92f)),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("نظرة تشغيلية سريعة", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onPrimaryContainer)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                HeroMetric("موصّل", data.orders.delivered.toString())
                HeroMetric("عميلات", data.orders.uniqueCustomers.toString())
                HeroMetric("زوار الآن", (presence?.online ?: 0).toString())
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                HeroMetric("قيد التوصيل", data.orders.shipped.toString())
                HeroMetric("نفد المخزون", data.products.outOfStock.toString())
                HeroMetric("قريب النفاد", data.products.lowStock.toString())
            }
        }
    }
}

@Composable
private fun HeroMetric(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onPrimaryContainer)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onPrimaryContainer)
    }
}

@Composable
private fun ShortcutCard(
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Card(
        modifier.clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(14.dp),
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
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null, Modifier.size(18.dp))
        }
    }
}

@Composable
private fun LiveVisitorsCard(presence: PresenceResponse?, onClick: () -> Unit) {
    val paused = presence != null && !presence.enabled
    Card(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .size(9.dp)
                            .clip(CircleShape)
                            .background(
                                when {
                                    paused -> Color(0xFFE0A31E)
                                    (presence?.online ?: 0) > 0 -> Color(0xFF2E9E5B)
                                    else -> Color(0xFF9AA0A6)
                                },
                            ),
                    )
                    Spacer(Modifier.width(7.dp))
                    Text(
                        if (paused) "تتبع الزوار موقوف" else "يتصفحون الآن",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
                Spacer(Modifier.size(4.dp))
                Text(
                    if (paused) "—" else presence?.online?.toString() ?: "—",
                    style = MaterialTheme.typography.displaySmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
                if (presence != null) {
                    Text(
                        if (paused) "اضغطي للتفعيل"
                        else "التطبيق ${presence.onlineApp} · الموقع ${presence.onlineWeb}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
            }
            if (presence != null && !paused) {
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        presence.lastHour.toString(),
                        style = MaterialTheme.typography.headlineSmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                    Text(
                        "خلال آخر ساعة",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
            }
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                null,
                Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }
    }
}

@Composable
fun DashboardScreen(
    onOpenCustomers: () -> Unit,
    onOpenInventory: () -> Unit,
    onOpenLiveVisitors: () -> Unit,
) {
    val repository = AdminApp.instance.repository
    var summary by remember { mutableStateOf<DashboardSummary?>(null) }
    var presence by remember { mutableStateOf<PresenceResponse?>(null) }
    var error by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }

    LaunchedEffect(reload) {
        error = ""
        summary = null
        runCatching { repository.dashboard() }
            .onSuccess { summary = it }
            .onFailure { error = it.message ?: "تعذر تحميل الإحصائيات" }
    }

    LaunchedEffect(Unit) {
        while (true) {
            runCatching { repository.presence() }.onSuccess { presence = it }
            delay(15_000)
        }
    }

    when {
        error.isNotEmpty() -> ErrorBox(error, { reload++ })
        summary == null -> LoadingBox()
        else -> {
            val data = summary!!
            val stats = listOf(
                Stat("المنتجات", data.products.total.toString()),
                Stat("معروضة", data.products.visible.toString()),
                Stat("مخفية", data.products.hidden.toString()),
                Stat("نفد المخزون", data.products.outOfStock.toString()),
                Stat("كل الطلبات", data.orders.total.toString()),
                Stat("قيد الانتظار", data.orders.pending.toString()),
                Stat("تم القبول", data.orders.processing.toString()),
                Stat("قيد التوصيل", data.orders.shipped.toString()),
                Stat("تم التوصيل", data.orders.delivered.toString()),
                Stat("ملغية", data.orders.canceled.toString()),
                Stat("عميلات", data.orders.uniqueCustomers.toString()),
                Stat("تثبيتات التطبيق", data.devices.installed.toString()),
            )
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(span = { GridItemSpan(2) }) { DashboardHeroCard(data, presence) }
                item(span = { GridItemSpan(2) }) { LiveVisitorsCard(presence, onOpenLiveVisitors) }
                item(span = { GridItemSpan(2) }) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        ShortcutCard(
                            "العملاء",
                            "${data.orders.uniqueCustomers} عميلة",
                            Modifier.weight(1f),
                            onOpenCustomers,
                        )
                        ShortcutCard(
                            "تنبيهات المخزون",
                            "${data.products.outOfStock} نفد · ${data.products.lowStock} قريب",
                            Modifier.weight(1f),
                            onOpenInventory,
                        )
                    }
                }
                items(stats) { stat ->
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = when {
                                stat.label.contains("طلب") || stat.label.contains("موصيل") -> MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.4f)
                                stat.label.contains("منتج") || stat.label.contains("المخزون") || stat.label.contains("نفد") -> MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.35f)
                                else -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.38f)
                            },
                        ),
                    ) {
                        Column(Modifier.padding(16.dp)) {
                            Text(
                                stat.label,
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(stat.value, style = MaterialTheme.typography.headlineSmall)
                        }
                    }
                }
            }
        }
    }
}
