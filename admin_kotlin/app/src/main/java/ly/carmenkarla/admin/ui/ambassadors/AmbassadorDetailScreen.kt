package ly.carmenkarla.admin.ui.ambassadors

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import ly.carmenkarla.admin.data.AmbassadorPerformance
import ly.carmenkarla.admin.data.OrderStatuses

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AmbassadorDetailScreen(data: AmbassadorPerformance, onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(data.ambassador.ambassadorName.ifBlank { "مندوب" }) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "رجوع") }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            Modifier
                .padding(padding)
                .fillMaxSize(),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("بيانات التواصل", style = MaterialTheme.typography.titleSmall)
                        if (data.ambassador.ambassadorPhone.isNotBlank()) {
                            Text(data.ambassador.ambassadorPhone, style = MaterialTheme.typography.bodyMedium)
                        }
                        if (data.ambassador.ambassadorAddress.isNotBlank()) {
                            Text(data.ambassador.ambassadorAddress, style = MaterialTheme.typography.labelMedium)
                        }
                        if (data.ambassador.email.isNotBlank()) {
                            Text(
                                data.ambassador.email,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("الأداء", style = MaterialTheme.typography.titleSmall)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            StatBlock("الطلبات", data.totalOrders.toString())
                            StatBlock("موصّلة", data.deliveredOrders.toString())
                            StatBlock("جارية", data.activeOrders.toString())
                            StatBlock("راجعة", data.returnedOrders.toString())
                        }
                        if (data.canceledOrders > 0) {
                            Text("ملغية: ${data.canceledOrders}", style = MaterialTheme.typography.labelSmall)
                        }
                        Text(
                            "نسبة نجاح التوصيل: ${data.successRate}%",
                            style = MaterialTheme.typography.labelMedium,
                        )
                        LinearProgressIndicator(
                            progress = { data.successRate / 100f },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }

            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("المبيعات والعمولات", style = MaterialTheme.typography.titleSmall)
                        MoneyLine("إجمالي المبيعات", data.totalSales)
                        MoneyLine("مبيعات موصّلة", data.deliveredSales)
                        HorizontalDivider()
                        MoneyLine("عمولة معتمدة", data.earnedCommission, highlight = true)
                        MoneyLine("عمولة قيد الانتظار", data.pendingCommission)
                        HorizontalDivider()
                        MoneyLine("مسحوب فعليًا", data.paidOut)
                        MoneyLine("طلبات سحب معلّقة", data.pendingWithdrawals)
                    }
                }
            }

            item { Text("آخر الطلبات", style = MaterialTheme.typography.titleSmall) }

            if (data.recentOrders.isEmpty()) {
                item { Text("لا توجد طلبات لهذا المندوب", style = MaterialTheme.typography.labelMedium) }
            }

            items(data.recentOrders, key = { it.orderId }) { order ->
                Card(Modifier.fillMaxWidth()) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                "#${order.orderId.takeLast(6)} · ${order.customerName}",
                                style = MaterialTheme.typography.bodyMedium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Text(
                                OrderStatuses.label(order.status),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Text(
                            "${"%.0f".format(order.grandTotal)} د.ل",
                            style = MaterialTheme.typography.titleSmall,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StatBlock(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleMedium)
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun MoneyLine(label: String, value: Double, highlight: Boolean = false) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(
            "${"%.2f".format(value)} د.ل",
            style = if (highlight) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodyMedium,
            color = if (highlight) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
        )
    }
}
