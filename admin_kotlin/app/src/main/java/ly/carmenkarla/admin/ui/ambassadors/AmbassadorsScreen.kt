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
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.AmbassadorPerformance
import ly.carmenkarla.admin.data.Withdrawal
import ly.carmenkarla.admin.data.buildAmbassadorPerformance
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox

private enum class Section(val label: String) {
    People("المندوبين"),
    Withdrawals("طلبات السحب"),
}

@Composable
fun AmbassadorsScreen() {
    var section by remember { mutableStateOf(Section.People) }
    var selected by remember { mutableStateOf<AmbassadorPerformance?>(null) }

    selected?.let { detail ->
        AmbassadorDetailScreen(detail) { selected = null }
        return
    }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Section.entries.forEach { entry ->
                FilterChip(
                    selected = section == entry,
                    onClick = { section = entry },
                    label = { Text(entry.label) },
                )
            }
        }
        when (section) {
            Section.People -> AmbassadorList { selected = it }
            Section.Withdrawals -> WithdrawalList()
        }
    }
}

@Composable
private fun AmbassadorList(onOpen: (AmbassadorPerformance) -> Unit) {
    val repository = AdminApp.instance.repository
    var items by remember { mutableStateOf<List<AmbassadorPerformance>?>(null) }
    var warning by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }

    LaunchedEffect(reload) {
        error = ""
        items = null
        runCatching {
            val people = repository.ambassadors()
            val orders = runCatching { repository.orders() }.getOrDefault(emptyList())
            val withdrawals = runCatching { repository.withdrawals() }.getOrDefault(emptyList())
            warning = people.warning
            buildAmbassadorPerformance(people.items, orders, withdrawals)
        }
            .onSuccess { items = it }
            .onFailure { error = it.message ?: "تعذر تحميل بيانات المندوبين" }
    }

    when {
        error.isNotEmpty() -> ErrorBox(error, { reload++ })
        items == null -> LoadingBox()
        else -> LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (warning.isNotBlank()) {
                item {
                    Text(
                        warning,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
            if (items!!.isEmpty()) {
                item { Text("لا يوجد مندوبون مسجّلون بعد") }
            }
            items(items!!, key = { it.ambassador.uid }) { row ->
                Card(
                    Modifier
                        .fillMaxWidth()
                        .clickable { onOpen(row) },
                ) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(
                                    row.ambassador.ambassadorName.ifBlank { "بدون اسم" },
                                    style = MaterialTheme.typography.titleSmall,
                                )
                                if (row.ambassador.ambassadorPhone.isNotBlank()) {
                                    Text(
                                        row.ambassador.ambassadorPhone,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                            }
                            Text(
                                "${"%.0f".format(row.earnedCommission)} د.ل",
                                style = MaterialTheme.typography.titleSmall,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                        Text(
                            "${row.totalOrders} طلب · ${row.deliveredOrders} موصّل · نجاح ${row.successRate}%",
                            style = MaterialTheme.typography.labelMedium,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun WithdrawalList() {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()
    var items by remember { mutableStateOf<List<Withdrawal>?>(null) }
    var error by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var busyId by remember { mutableStateOf("") }

    LaunchedEffect(reload) {
        error = ""
        items = null
        runCatching { repository.withdrawals() }
            .onSuccess { items = it }
            .onFailure { error = it.message ?: "تعذر تحميل طلبات السحب" }
    }

    fun act(id: String, status: String) {
        busyId = id
        message = ""
        scope.launch {
            runCatching { repository.setWithdrawalStatus(id, status) }
                .onSuccess { message = "تم التحديث ✓"; reload++ }
                .onFailure { message = it.message ?: "تعذر التحديث" }
            busyId = ""
        }
    }

    when {
        error.isNotEmpty() -> ErrorBox(error, { reload++ })
        items == null -> LoadingBox()
        else -> LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (message.isNotEmpty()) {
                item {
                    Text(
                        message,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
            if (items!!.isEmpty()) {
                item { Text("لا توجد طلبات سحب") }
            }
            items(items!!, key = { it.id }) { request ->
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column {
                                Text(
                                    request.ambassadorName.ifBlank { "بدون اسم" },
                                    style = MaterialTheme.typography.titleSmall,
                                )
                                Text(request.ambassadorPhone, style = MaterialTheme.typography.labelSmall)
                            }
                            Text(
                                "${"%.2f".format(request.amount)} د.ل",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                        Text(
                            statusLabel(request.status),
                            style = MaterialTheme.typography.labelMedium,
                        )
                        val actions = nextStatuses(request.status)
                        if (actions.isNotEmpty()) {
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                actions.forEach { (key, label) ->
                                    OutlinedButton(
                                        onClick = { act(request.id, key) },
                                        enabled = busyId != request.id,
                                    ) { Text(label) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun statusLabel(status: String) = when (status) {
    "pending" -> "بانتظار المراجعة"
    "approved" -> "معتمد"
    "paid" -> "مدفوع"
    "rejected" -> "مرفوض"
    else -> status
}

/** Mirrors the transitions the backend accepts, so no button can produce a 409. */
private fun nextStatuses(status: String): List<Pair<String, String>> = when (status) {
    "pending" -> listOf("approved" to "اعتماد", "rejected" to "رفض")
    "approved" -> listOf("paid" to "تم الدفع", "rejected" to "رفض")
    else -> emptyList()
}
