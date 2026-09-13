package ly.carmenkarla.admin.ui.ambassadors

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.AmbassadorFinanceProfile
import ly.carmenkarla.admin.data.AmbassadorFinanceSummaryResponse
import ly.carmenkarla.admin.data.Withdrawal
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox
import java.util.Locale

private enum class Section(val label: String) {
    People("المندوبات"),
    Withdrawals("طلبات السحب"),
}

private enum class PeopleFilter(val label: String) {
    All("الكل"),
    Attention("تحتاج متابعة"),
    WithBalance("لديهن رصيد"),
}

private enum class PeopleSort(val label: String) {
    Approved("الأعلى اعتمادًا"),
    Available("الأعلى رصيدًا"),
    Sales("الأعلى مبيعات"),
    Recent("الأحدث نشاطًا"),
}

@Composable
fun AmbassadorsScreen() {
    var section by remember { mutableStateOf(Section.People) }
    var selectedKey by remember { mutableStateOf<String?>(null) }

    selectedKey?.let { key ->
        AmbassadorDetailScreen(profileKey = key) { selectedKey = null }
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
            Section.People -> AmbassadorList { selectedKey = it.key }
            Section.Withdrawals -> WithdrawalList()
        }
    }
}

@Composable
private fun AmbassadorList(onOpen: (AmbassadorFinanceProfile) -> Unit) {
    val repository = AdminApp.instance.repository
    var envelope by remember { mutableStateOf<AmbassadorFinanceSummaryResponse?>(null) }
    var error by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var query by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf(PeopleFilter.All) }
    var sort by remember { mutableStateOf(PeopleSort.Approved) }

    LaunchedEffect(reload) {
        error = ""
        envelope = null
        runCatching { repository.ambassadorFinanceSummary() }
            .onSuccess { envelope = it }
            .onFailure { error = it.message ?: "تعذر تحميل بيانات المندوبات" }
    }

    when {
        error.isNotEmpty() -> ErrorBox(error, { reload++ })
        envelope == null -> LoadingBox()
        else -> {
            val search = query.trim()
            val visible = envelope!!.items
                .filter { item ->
                    when (filter) {
                        PeopleFilter.All -> true
                        PeopleFilter.Attention -> item.needsAttention
                        PeopleFilter.WithBalance -> item.availableBalance > 0.0
                    }
                }
                .filter { item ->
                    search.isBlank() ||
                        item.displayName.contains(search, true) ||
                        item.phone.contains(search) ||
                        item.email.contains(search, true)
                }
                .sortedWith(
                    when (sort) {
                        PeopleSort.Approved -> compareByDescending<AmbassadorFinanceProfile> { it.approvedCommission }
                            .thenByDescending { it.availableBalance }
                        PeopleSort.Available -> compareByDescending<AmbassadorFinanceProfile> { it.availableBalance }
                            .thenByDescending { it.approvedCommission }
                        PeopleSort.Sales -> compareByDescending<AmbassadorFinanceProfile> { it.sales }
                            .thenByDescending { it.ordersCount }
                        PeopleSort.Recent -> compareByDescending<AmbassadorFinanceProfile> { it.lastOrderMs }
                            .thenByDescending { it.sales }
                    },
                )

            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (envelope!!.warning.isNotBlank() || envelope!!.source == "legacy") {
                    item {
                        CompatibilityBanner(
                            title = if (envelope!!.source == "legacy") "وضع التوافق الذكي" else "تنبيه مزامنة",
                            body = envelope!!.warning.ifBlank {
                                "بعض تفاصيل سجل العمولات المتقدم غير متاحة من الخادم حاليًا، لذلك نعرض أفضل ملخص متاح من الطلبات والسحوبات بدون إيقاف عمل اللوحة."
                            },
                            accent = if (envelope!!.source == "legacy") MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.error,
                            chips = buildList {
                                if (envelope!!.source == "legacy") add("عرض تقديري محسّن")
                                add("لا يوجد تعطل")
                                add("البيانات الأساسية متاحة")
                            },
                        )
                    }
                }
                item { AmbassadorProgramHero(envelope!!, compatibilityMode = envelope!!.source == "legacy") }
                item {
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        label = { Text("بحث باسم أو هاتف أو بريد") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                item {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        PeopleFilter.entries.forEach { entry ->
                            FilterChip(
                                selected = filter == entry,
                                onClick = { filter = entry },
                                label = { Text(entry.label) },
                            )
                        }
                    }
                }
                item {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        PeopleSort.entries.forEach { entry ->
                            FilterChip(
                                selected = sort == entry,
                                onClick = { sort = entry },
                                label = { Text(entry.label) },
                            )
                        }
                    }
                }
                if (visible.isEmpty()) {
                    item { EmptyFinanceState("لا توجد نتائج مطابقة") }
                }
                items(visible, key = { if (it.key.isNotBlank()) it.key else it.uid + it.displayName }) { row ->
                    AmbassadorFinanceCard(row, onOpen, compatibilityMode = envelope!!.source == "legacy")
                }
            }
        }
    }
}

@Composable
private fun AmbassadorProgramHero(data: AmbassadorFinanceSummaryResponse, compatibilityMode: Boolean) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.42f)),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                "نظرة مالية سريعة",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                FinanceMetric("المندوبات", data.summary.ambassadorCount.toString())
                FinanceMetric("الطلبات", data.summary.ordersCount.toString())
                FinanceMetric("المفتوحة", data.summary.openOrders.toString())
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                FinanceMetric(if (compatibilityMode) "مبيعات موصّلة" else "المبيعات", money0(data.summary.sales))
                FinanceMetric(if (compatibilityMode) "موصّل" else "المعتمد", money0(data.summary.approvedCommission))
                FinanceMetric("القابل للسحب", money0(data.summary.availableBalance))
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                FinanceMetric(if (compatibilityMode) "قيد التقدير" else "بانتظار اعتماد", money0(data.summary.pendingApprovalCommission))
                FinanceMetric(if (compatibilityMode) "جاري" else "الجاري", money0(data.summary.pipelineCommission))
                FinanceMetric("محجوز سحب", money0(data.summary.reservedWithdrawals))
            }
        }
    }
}

@Composable
private fun FinanceMetric(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AmbassadorFinanceCard(
    item: AmbassadorFinanceProfile,
    onOpen: (AmbassadorFinanceProfile) -> Unit,
    compatibilityMode: Boolean,
) {
    Card(
        Modifier
            .fillMaxWidth()
            .clickable { onOpen(item) },
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(item.displayName, style = MaterialTheme.typography.titleSmall)
                    val contact = listOf(item.phone, item.email).filter { it.isNotBlank() }.joinToString(" · ")
                    if (contact.isNotBlank()) {
                        Text(
                            contact,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Text(
                    money0(item.availableBalance),
                    style = MaterialTheme.typography.titleSmall,
                    color = if (item.availableBalance >= 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                )
            }
            if (item.needsAttention) {
                Text(
                    "تحتاج مراجعة: يوجد اعتماد أو سحب بانتظار الإجراء",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
            Text(
                "${item.ordersCount} طلب · ${item.deliveredOrders} موصّل · نجاح ${item.deliveryRate}%",
                style = MaterialTheme.typography.labelMedium,
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                FinanceMetric(if (compatibilityMode) "موصّل" else "معتمد", money0(item.approvedCommission))
                FinanceMetric(if (compatibilityMode) "تقديري" else "بانتظار", money0(item.pendingApprovalCommission))
                FinanceMetric("جاري", money0(item.pipelineCommission))
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                FinanceMetric("مبيعات موصّلة", money0(item.sales))
                FinanceMetric("محجوز", money0(item.reservedWithdrawals))
                FinanceMetric("سحب مدفوع", money0(item.paidWithdrawalsTotal))
            }
        }
    }
}

@Composable
private fun EmptyFinanceState(label: String) {
    Card(Modifier.fillMaxWidth()) {
        Text(
            label,
            modifier = Modifier.padding(18.dp),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun CompatibilityBanner(
    title: String,
    body: String,
    accent: androidx.compose.ui.graphics.Color,
    chips: List<String>,
) {
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(title, style = MaterialTheme.typography.titleSmall, color = accent)
                    Text(
                        body,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Box {
                    Surface(
                        color = accent.copy(alpha = 0.12f),
                        contentColor = accent,
                        shape = MaterialTheme.shapes.small,
                    ) {
                        Text(
                            if (title.contains("التوافق")) "متاح" else "تنبيه",
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                            style = MaterialTheme.typography.labelSmall,
                        )
                    }
                }
            }
            if (chips.isNotEmpty()) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    chips.forEach { chip ->
                        Surface(
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            shape = MaterialTheme.shapes.small,
                        ) {
                            Text(
                                chip,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                style = MaterialTheme.typography.labelSmall,
                            )
                        }
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
                                money2(request.amount),
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                        Text(statusLabel(request.status), style = MaterialTheme.typography.labelMedium)
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

private fun nextStatuses(status: String): List<Pair<String, String>> = when (status) {
    "pending" -> listOf("approved" to "اعتماد", "rejected" to "رفض")
    "approved" -> listOf("paid" to "تم الدفع", "rejected" to "رفض")
    else -> emptyList()
}

private fun money0(value: Double): String = String.format(Locale.US, "%.0f د.ل", value)

private fun money2(value: Double): String = String.format(Locale.US, "%.2f د.ل", value)
