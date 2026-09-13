package ly.carmenkarla.admin.ui.ambassadors

import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.AmbassadorCommissionRecord
import ly.carmenkarla.admin.data.AmbassadorFinanceEvent
import ly.carmenkarla.admin.data.AmbassadorFinanceProfile
import ly.carmenkarla.admin.data.Order
import ly.carmenkarla.admin.data.OrderStatuses
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private enum class ManualKind(val label: String, val sign: Double) {
    Add("إضافة قيد", 1.0),
    Deduct("خصم من الرصيد", -1.0),
}

private data class CommissionEditorState(
    val id: String,
    val title: String,
    val initialAmount: Double,
    val initialStatus: String,
    val initialNote: String,
    val isOrder: Boolean,
)

private data class DeleteCommissionState(
    val id: String,
    val title: String,
    val amount: Double,
    val isOrder: Boolean,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AmbassadorDetailScreen(profileKey: String, onBack: () -> Unit) {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()
    var data by remember(profileKey) { mutableStateOf<AmbassadorFinanceProfile?>(null) }
    var source by remember { mutableStateOf("") }
    var warning by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var busy by remember { mutableStateOf(false) }
    var manualKind by remember { mutableStateOf<ManualKind?>(null) }
    var editor by remember { mutableStateOf<CommissionEditorState?>(null) }
    var deleting by remember { mutableStateOf<DeleteCommissionState?>(null) }

    LaunchedEffect(profileKey, reload) {
        error = ""
        runCatching { repository.ambassadorFinanceDetail(profileKey) }
            .onSuccess {
                data = it.item
                source = it.source
                warning = it.warning
            }
            .onFailure { error = it.message ?: "تعذر تحميل ملف المندوبة" }
    }

    val profile = data
    if (error.isNotEmpty() && profile == null) {
        ErrorBox(error, { reload++ })
        return
    }
    if (profile == null) {
        LoadingBox()
        return
    }

    val compatibilityMode = source == "legacy"

    manualKind?.let { kind ->
        ManualAdjustmentDialog(
            kind = kind,
            onDismiss = { manualKind = null },
            onConfirm = { amount, status, note ->
                scope.launch {
                    busy = true
                    message = ""
                    runCatching {
                        repository.createManualCommission(
                            profile = profile,
                            amount = amount * kind.sign,
                            note = note,
                            status = status,
                        )
                    }
                        .onSuccess {
                            message = "تم حفظ القيد المالي ✓"
                            manualKind = null
                            reload++
                        }
                        .onFailure { message = it.message ?: "تعذر حفظ القيد" }
                    busy = false
                }
            },
        )
    }

    editor?.let { state ->
        CommissionEditorDialog(
            title = state.title,
            initialAmount = state.initialAmount,
            initialStatus = state.initialStatus,
            initialNote = state.initialNote,
            onDismiss = { editor = null },
            onConfirm = { amount, status, note ->
                scope.launch {
                    busy = true
                    message = ""
                    runCatching {
                        if (state.isOrder) {
                            repository.updateOrderCommission(
                                orderId = state.id,
                                status = status,
                                approvedAmount = amount,
                                note = note,
                            )
                        } else {
                            repository.updateManualCommission(
                                recordId = state.id,
                                status = status,
                                approvedAmount = amount,
                                note = note,
                            )
                        }
                    }
                        .onSuccess {
                            message = "تم تحديث العمولة ✓"
                            editor = null
                            reload++
                        }
                        .onFailure { message = it.message ?: "تعذر تحديث العمولة" }
                    busy = false
                }
            },
        )
    }

    deleting?.let { state ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        busy = true
                        message = ""
                        runCatching {
                            if (state.isOrder) {
                                repository.updateOrderCommission(
                                    orderId = state.id,
                                    status = "canceled",
                                    approvedAmount = state.amount,
                                    note = "تم إلغاء العمولة من لوحة التحكم",
                                )
                            } else {
                                repository.updateManualCommission(
                                    recordId = state.id,
                                    status = "canceled",
                                    approvedAmount = state.amount,
                                    note = "تم إلغاء القيد من لوحة التحكم",
                                )
                            }
                        }
                            .onSuccess {
                                message = "تم حذف / إلغاء العمولة ✓"
                                deleting = null
                                reload++
                            }
                            .onFailure { message = it.message ?: "تعذر حذف العمولة" }
                        busy = false
                    }
                }) { Text("تأكيد الحذف") }
            },
            dismissButton = {
                TextButton(onClick = { deleting = null }) { Text("إلغاء") }
            },
            title = { Text("حذف العمولة") },
            text = {
                Text("سيتم إلغاء ${state.title} بقيمة ${money2(state.amount)}. يمكنكِ الرجوع لاحقًا من خلال تعديل الحالة إذا كان الخادم يدعم ذلك.")
            },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(profile.displayName) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "رجوع") }
                },
                actions = {
                    IconButton(onClick = { reload++ }, enabled = !busy) {
                        Icon(Icons.Default.Refresh, "تحديث")
                    }
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
            if (warning.isNotBlank() || compatibilityMode) {
                item {
                    DetailStatusBanner(
                        compatibilityMode = compatibilityMode,
                        warning = warning,
                    )
                }
            }
            if (message.isNotBlank()) {
                item {
                    Text(
                        message,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (message.contains("✓")) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                    )
                }
            }

            item { ContactCard(profile) }
            item { PerformanceCard(profile) }
            item { FinanceOverviewCard(profile, compatibilityMode = compatibilityMode) }
            item {
                if (compatibilityMode) {
                    ReadOnlyActionsCard()
                } else {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { manualKind = ManualKind.Add }, enabled = !busy) {
                            Text("إضافة قيد")
                        }
                        OutlinedButton(onClick = { manualKind = ManualKind.Deduct }, enabled = !busy) {
                            Text("خصم رصيد")
                        }
                    }
                }
            }

            item { Text("الطلبات", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
            if (profile.orders.isEmpty()) {
                item { DetailEmptyCard("لا توجد طلبات مرتبطة بهذه المندوبة") }
            }
            items(profile.orders, key = { it.orderId }) { order ->
                OrderCommissionCard(
                    order = order,
                    enabled = !busy && !compatibilityMode,
                    compatibilityMode = compatibilityMode,
                    onDelete = {
                        deleting = DeleteCommissionState(
                            id = order.orderId,
                            title = "عمولة الطلب #${order.orderId.takeLast(6)}",
                            amount = orderCommissionAmount(order),
                            isOrder = true,
                        )
                    },
                    onEdit = {
                        editor = CommissionEditorState(
                            id = order.orderId,
                            title = "عمولة الطلب #${order.orderId.takeLast(6)}",
                            initialAmount = orderCommissionAmount(order),
                            initialStatus = orderCommissionStatus(order),
                            initialNote = order.commission.note,
                            isOrder = true,
                        )
                    },
                )
            }

            item { Text("القيود المالية", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
            if (profile.records.isEmpty()) {
                item { DetailEmptyCard("لا توجد قيود مالية بعد") }
            }
            items(profile.records, key = { it.id }) { record ->
                CommissionRecordCard(
                    record = record,
                    enabled = !busy && !compatibilityMode,
                    compatibilityMode = compatibilityMode,
                    onDelete = {
                        deleting = DeleteCommissionState(
                            id = record.id,
                            title = if (record.sourceType == "manual") "القيد اليدوي" else "عمولة الطلب",
                            amount = record.approvedAmount.takeIf { it != 0.0 } ?: record.baseAmount,
                            isOrder = false,
                        )
                    },
                    onEdit = {
                        editor = CommissionEditorState(
                            id = record.id,
                            title = "تعديل قيد مالي",
                            initialAmount = record.approvedAmount.takeIf { it != 0.0 } ?: record.baseAmount,
                            initialStatus = record.status,
                            initialNote = record.note,
                            isOrder = false,
                        )
                    },
                )
            }

            item { Text("السجل الزمني", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
            if (profile.history.isEmpty()) {
                item { DetailEmptyCard("لا يوجد سجل زمني بعد") }
            }
            items(profile.history, key = { it.id + it.createdAtMs }) { event ->
                FinanceHistoryCard(event)
            }
        }
    }
}

@Composable
private fun DetailStatusBanner(
    compatibilityMode: Boolean,
    warning: String,
) {
    val accent = if (compatibilityMode) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.error
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (compatibilityMode) "عرض ذكي متوافق" else "تنبيه خدمة",
                        style = MaterialTheme.typography.titleSmall,
                        color = accent,
                    )
                    Text(
                        warning.ifBlank {
                            if (compatibilityMode) {
                                "الملف المالي معروض الآن بوضع قراءة محسّن يعتمد على الطلبات والسحوبات المتوفرة، لضمان استمرار العمل بدون أخطاء أو صفحة فارغة."
                            } else {
                                "تعذر تحميل بعض تفاصيل الخدمة حاليًا."
                            }
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Surface(
                    color = accent.copy(alpha = 0.12f),
                    contentColor = accent,
                    shape = MaterialTheme.shapes.small,
                ) {
                    Text(
                        if (compatibilityMode) "قراءة فقط" else "تنبيه",
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        style = MaterialTheme.typography.labelSmall,
                    )
                }
            }
            Row(
                Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                listOf(
                    if (compatibilityMode) "ملخص موحد" else "تحقق من الخادم",
                    if (compatibilityMode) "بدون تعطيل للشاشة" else "بعض الوظائف محدودة",
                    if (compatibilityMode) "الأرقام الأساسية متاحة" else "أعيدي المحاولة لاحقًا",
                ).forEach { chip ->
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

@Composable
private fun ReadOnlyActionsCard() {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("الإجراءات المتقدمة", style = MaterialTheme.typography.titleSmall)
            Text(
                "إدارة العمولات اليدوية وتعديل القيود متاحة فور نشر تحديث الخادم. حاليًا يمكنكِ متابعة الأداء والرصيد والسحوبات بشكل احترافي بدون ظهور أخطاء.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun ContactCard(data: AmbassadorFinanceProfile) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("بيانات التواصل", style = MaterialTheme.typography.titleSmall)
            listOf(data.phone, data.address, data.email).filter { it.isNotBlank() }.forEach {
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }
            Text(
                if (data.status == "active") "الحالة: نشطة" else "الحالة: ${data.status}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun PerformanceCard(data: AmbassadorFinanceProfile) {
    Card(Modifier.fillMaxWidth(), colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f))) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("الأداء", style = MaterialTheme.typography.titleSmall)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                StatBlock("الطلبات", data.ordersCount.toString())
                StatBlock("موصّلة", data.deliveredOrders.toString())
                StatBlock("جارية", data.openOrders.toString())
                StatBlock("ملغية", data.canceledOrders.toString())
            }
            Text("نسبة النجاح: ${data.deliveryRate}%", style = MaterialTheme.typography.labelMedium)
            LinearProgressIndicator(progress = { data.deliveryRate / 100f }, modifier = Modifier.fillMaxWidth())
        }
    }
}

@Composable
private fun FinanceOverviewCard(data: AmbassadorFinanceProfile, compatibilityMode: Boolean) {
    Card(Modifier.fillMaxWidth(), colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.38f))) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("المبيعات والعمولات", style = MaterialTheme.typography.titleSmall)
            MoneyLine(if (compatibilityMode) "مبيعات الطلبات الموصّلة" else "إجمالي المبيعات", data.sales)
            MoneyLine("متوسط الطلب", data.averageOrder)
            HorizontalDivider()
            MoneyLine(if (compatibilityMode) "عمولات الطلبات الموصّلة" else "عمولة معتمدة", data.approvedCommission, highlight = true)
            MoneyLine(if (compatibilityMode) "عمولات تقديرية" else "بانتظار الاعتماد", data.pendingApprovalCommission)
            MoneyLine("جارية", data.pipelineCommission)
            if (!compatibilityMode) {
                MoneyLine("تعديلات يدوية", data.manualAdjustments)
            }
            HorizontalDivider()
            MoneyLine("القابل للسحب", data.availableBalance, highlight = true)
            MoneyLine("محجوز للسحب", data.reservedWithdrawals)
            MoneyLine("سحب مدفوع", data.paidWithdrawalsTotal)
        }
    }
}

@Composable
private fun OrderCommissionCard(
    order: Order,
    enabled: Boolean,
    compatibilityMode: Boolean,
    onDelete: () -> Unit,
    onEdit: () -> Unit,
) {
    val delivered = order.status == "delivered"
    Card(Modifier.fillMaxWidth(), colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        "#${order.orderId.takeLast(6)} · ${order.customerName.ifBlank { "بدون اسم" }}",
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
                Text(money2(order.grandTotal), style = MaterialTheme.typography.titleSmall)
            }
            MoneyLine(
                "العمولة الأساسية",
                order.commission.baseAmount.takeIf { it > 0 } ?: order.fallbackCommission(),
            )
            MoneyLine("العمولة الحالية", orderCommissionAmount(order), highlight = true)
            Text(
                if (compatibilityMode) {
                    "الوضع: ${legacyOrderUiLabel(order.status)}"
                } else {
                    "الحالة: ${commissionStatusLabel(orderCommissionStatus(order))}"
                },
                style = MaterialTheme.typography.labelMedium,
                color = if (compatibilityMode) legacyOrderUiColor(order.status) else commissionStatusColor(orderCommissionStatus(order)),
            )
            if (order.commission.note.isNotBlank()) {
                Text(order.commission.note, style = MaterialTheme.typography.labelSmall)
            }
            if (delivered && !compatibilityMode) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = onEdit, enabled = enabled, modifier = Modifier.weight(1f)) { Text("إدارة العمولة") }
                    OutlinedButton(onClick = onDelete, enabled = enabled, modifier = Modifier.weight(1f)) { Text("حذف العمولة") }
                }
            } else if (delivered && compatibilityMode) {
                Text(
                    "إدارة العمولة ستظهر هنا تلقائيًا بعد تحديث الخادم.",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun CommissionRecordCard(
    record: AmbassadorCommissionRecord,
    enabled: Boolean,
    compatibilityMode: Boolean,
    onDelete: () -> Unit,
    onEdit: () -> Unit,
) {
    Card(Modifier.fillMaxWidth(), colors = androidx.compose.material3.CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (record.sourceType == "manual") "قيد يدوي" else "قيد مرتبط بطلب #${record.orderId.takeLast(6)}",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(
                        commissionStatusLabel(record.status),
                        style = MaterialTheme.typography.labelSmall,
                        color = commissionStatusColor(record.status),
                    )
                }
                Text(
                    money2(record.approvedAmount.takeIf { it != 0.0 } ?: record.baseAmount),
                    style = MaterialTheme.typography.titleSmall,
                )
            }
            if (record.note.isNotBlank()) {
                Text(record.note, style = MaterialTheme.typography.labelSmall)
            }
            if (record.sourceType == "manual" && !compatibilityMode) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = onEdit, enabled = enabled, modifier = Modifier.weight(1f)) { Text("تعديل القيد") }
                    OutlinedButton(onClick = onDelete, enabled = enabled, modifier = Modifier.weight(1f)) { Text("حذف العمولة") }
                }
            } else if (record.sourceType == "manual" && compatibilityMode) {
                Text(
                    "تعديل القيود اليدوية غير متاح في وضع التوافق الحالي.",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun FinanceHistoryCard(event: AmbassadorFinanceEvent) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(event.label.ifBlank { event.type }, style = MaterialTheme.typography.bodyMedium)
                Text(money2(event.amount), style = MaterialTheme.typography.titleSmall)
            }
            Text(
                "${commissionStatusLabel(event.status)} · ${formatDate(event.createdAtMs)}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (event.note.isNotBlank()) {
                Text(event.note, style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
private fun DetailEmptyCard(label: String) {
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
private fun ManualAdjustmentDialog(
    kind: ManualKind,
    onDismiss: () -> Unit,
    onConfirm: (amount: Double, status: String, note: String) -> Unit,
) {
    var amount by remember(kind) { mutableStateOf("") }
    var note by remember(kind) { mutableStateOf("") }
    var status by remember(kind) { mutableStateOf("approved") }
    var localError by remember(kind) { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                val parsed = amount.replace(',', '.').toDoubleOrNull()
                if (parsed == null || parsed <= 0) {
                    localError = "أدخلي مبلغًا صحيحًا أكبر من صفر"
                    return@TextButton
                }
                if (note.isBlank()) {
                    localError = "أضيفي ملاحظة للمرجع المالي"
                    return@TextButton
                }
                onConfirm(parsed, status, note.trim())
            }) { Text("حفظ") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("إلغاء") } },
        title = { Text(kind.label) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it },
                    label = { Text("المبلغ") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("ملاحظة") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(
                    Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    listOf(
                        "approved" to "معتمد",
                        "pending" to "معلّق",
                        "canceled" to "ملغي",
                    ).forEach { (key, label) ->
                        FilterChip(selected = status == key, onClick = { status = key }, label = { Text(label) })
                    }
                }
                if (localError.isNotBlank()) {
                    Text(localError, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
                }
            }
        },
    )
}

@Composable
private fun CommissionEditorDialog(
    title: String,
    initialAmount: Double,
    initialStatus: String,
    initialNote: String,
    onDismiss: () -> Unit,
    onConfirm: (amount: Double, status: String, note: String) -> Unit,
) {
    var amount by remember(title, initialAmount) { mutableStateOf(trimAmount(initialAmount)) }
    var note by remember(title, initialNote) { mutableStateOf(initialNote) }
    var status by remember(title, initialStatus) { mutableStateOf(initialStatus.ifBlank { "pending" }) }
    var localError by remember(title) { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                val parsed = amount.replace(',', '.').toDoubleOrNull()
                if (parsed == null || parsed < 0) {
                    localError = "أدخلي مبلغًا صحيحًا غير سالب"
                    return@TextButton
                }
                onConfirm(parsed, status, note.trim())
            }) { Text("حفظ") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("إلغاء") } },
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it },
                    label = { Text("المبلغ") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("ملاحظة") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(
                    Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    listOf(
                        "pending" to "معلّقة",
                        "approved" to "معتمدة",
                        "canceled" to "ملغية",
                    ).forEach { (key, label) ->
                        FilterChip(selected = status == key, onClick = { status = key }, label = { Text(label) })
                    }
                }
                if (localError.isNotBlank()) {
                    Text(localError, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
                }
            }
        },
    )
}

@Composable
private fun StatBlock(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleMedium)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun MoneyLine(label: String, value: Double, highlight: Boolean = false) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(
            money2(value),
            style = if (highlight) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodyMedium,
            color = if (highlight) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
        )
    }
}

private fun orderCommissionAmount(order: Order): Double =
    when {
        order.commission.approvedAmount > 0 -> order.commission.approvedAmount
        order.commission.baseAmount > 0 -> order.commission.baseAmount
        else -> order.fallbackCommission()
    }

private fun orderCommissionStatus(order: Order): String =
    order.commission.state.ifBlank {
        order.commission.status.ifBlank {
            if (order.status == "delivered") "pending" else "pipeline"
        }
    }

@Composable
private fun commissionStatusColor(status: String): Color = when (status) {
    "approved" -> MaterialTheme.colorScheme.primary
    "pending" -> MaterialTheme.colorScheme.tertiary
    "pipeline" -> MaterialTheme.colorScheme.secondary
    "canceled" -> MaterialTheme.colorScheme.error
    else -> MaterialTheme.colorScheme.onSurfaceVariant
}

private fun commissionStatusLabel(status: String): String = when (status) {
    "approved" -> "معتمدة"
    "pending" -> "معلّقة"
    "pipeline" -> "جارية"
    "canceled" -> "ملغية"
    else -> status
}

@Composable
private fun legacyOrderUiColor(status: String): Color = when (status) {
    "delivered" -> MaterialTheme.colorScheme.primary
    "returned", "returning", "canceled" -> MaterialTheme.colorScheme.error
    else -> MaterialTheme.colorScheme.secondary
}

private fun legacyOrderUiLabel(status: String): String = when (status) {
    "delivered" -> "طلب موصّل بعمولة تقديرية"
    "returned", "returning", "canceled" -> "طلب ملغي أو مُرجع"
    else -> "طلب جارٍ بعمولة تقديرية"
}

private fun formatDate(value: Long): String {
    if (value <= 0) return ""
    return SimpleDateFormat("dd/MM/yyyy · hh:mm a", Locale("ar")).format(Date(value))
}

private fun trimAmount(value: Double): String =
    if (value == value.toLong().toDouble()) value.toLong().toString() else String.format(Locale.US, "%.2f", value)

private fun money2(value: Double): String = String.format(Locale.US, "%.2f د.ل", value)
