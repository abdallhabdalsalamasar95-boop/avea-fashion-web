package ly.carmenkarla.admin.ui.orders

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.Order
import ly.carmenkarla.admin.data.OrderStatuses
import ly.carmenkarla.admin.data.Product
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox
import coil.compose.AsyncImage
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Pseudo-filter key for canceled orders auto-hidden after 24 hours. */
private const val ARCHIVE = "__archive__"

@Composable
fun OrdersScreen() {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()

    var orders by remember { mutableStateOf<List<Order>?>(null) }
    var error by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf("") }
    var query by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var busyOrderId by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var baseUrl by remember { mutableStateOf("") }
    var showExternalSale by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        baseUrl = AdminApp.instance.repository.settings.currentBaseUrl().trimEnd('/')
    }

    // Loaded unfiltered so every chip can show a live count and switching needs no refetch.
    LaunchedEffect(reload) {
        error = ""
        orders = null
        runCatching { repository.orders() }
            .onSuccess { orders = it }
            .onFailure { error = it.message ?: "تعذر تحميل الطلبات" }
    }

    fun refresh() {
        reload++
    }

    Column(Modifier.fillMaxSize()) {
        Button(
            onClick = { showExternalSale = true },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
        ) { Text("+ مبيعة خارجية") }
        val loaded = orders.orEmpty()
        // Canceled orders older than a day only clutter the panel; keep them behind the archive chip.
        val staleCutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
        val archived = loaded.filter { it.status == "canceled" && it.createdAtMs in 1 until staleCutoff }
        val active = loaded - archived.toSet()
        val pool = if (filter == ARCHIVE) archived else active

        val visible = pool
            .filter { filter == ARCHIVE || filter.isEmpty() || it.status == filter }
            .filter { order ->
                val term = query.trim()
                term.isEmpty() ||
                    order.customerName.contains(term, true) ||
                    order.customerPhone.contains(term) ||
                    order.city.contains(term, true) ||
                    order.orderId.contains(term, true)
            }

        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            label = { Text("ابحث بالاسم أو الهاتف أو رقم الطلب") },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
        )

        Row(
            Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            FilterChip(
                selected = filter.isEmpty(),
                onClick = { filter = "" },
                label = { Text("الكل (${active.size})") },
            )
            OrderStatuses.all.forEach { (key, label) ->
                val count = active.count { it.status == key }
                FilterChip(
                    selected = filter == key,
                    onClick = { filter = key },
                    label = { Text("$label ($count)") },
                )
            }
            if (archived.isNotEmpty()) {
                FilterChip(
                    selected = filter == ARCHIVE,
                    onClick = { filter = ARCHIVE },
                    label = { Text("الأرشيف (${archived.size})") },
                )
            }
        }

        if (message.isNotEmpty()) {
            Text(
                message,
                Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary,
            )
        }

        when {
            error.isNotEmpty() -> ErrorBox(error, ::refresh)
            orders == null -> LoadingBox()
            visible.isEmpty() -> Column(
                Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    if (query.isNotBlank()) "لا توجد نتائج للبحث"
                    else "لا توجد طلبات في هذه الحالة",
                )
            }
            else -> LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(visible, key = { it.orderId }) { order ->
                    OrderCard(
                        order = order,
                        baseUrl = baseUrl,
                        busy = busyOrderId == order.orderId,
                        onStatus = { status ->
                            busyOrderId = order.orderId
                            message = ""
                            scope.launch {
                                runCatching { repository.setOrderStatus(order.orderId, status) }
                                    .onSuccess { message = "تم تحديث الحالة ✓"; refresh() }
                                    .onFailure { message = it.message ?: "تعذر التحديث" }
                                busyOrderId = ""
                            }
                        },
                        onDispatch = {
                            busyOrderId = order.orderId
                            message = ""
                            scope.launch {
                                runCatching { repository.dispatchOrder(order.orderId) }
                                    .onSuccess { message = "تم إرسال الطلب لدرب السبيل ✓"; refresh() }
                                    .onFailure { message = it.message ?: "تعذر الإرسال" }
                                busyOrderId = ""
                            }
                        },
                    )
                }
            }
        }
    }

    if (showExternalSale) {
        ExternalSaleDialog(
            onDismiss = { showExternalSale = false },
            onSaved = {
                showExternalSale = false
                refresh()
                message = "تم حفظ المبيعة الخارجية ✓"
            },
        )
    }
}

@Composable
private fun ExternalSaleDialog(onDismiss: () -> Unit, onSaved: () -> Unit) {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()
    var products by remember { mutableStateOf<List<Product>>(emptyList()) }
    var selected by remember { mutableStateOf<Product?>(null) }
    var query by remember { mutableStateOf("") }
    var size by remember { mutableStateOf("") }
    var color by remember { mutableStateOf("") }
    var quantity by remember { mutableStateOf("1") }
    var salePrice by remember { mutableStateOf("") }
    var customerName by remember { mutableStateOf("") }
    var customerPhone by remember { mutableStateOf("") }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }

    LaunchedEffect(Unit) { products = runCatching { repository.products() }.getOrDefault(emptyList()) }
    val filtered = products.filter { query.isBlank() || it.name.contains(query, true) || it.productCode.contains(query, true) }
    val selectedStock = selected?.sizeQuantities?.get(size)?.takeIf { size.isNotBlank() }
        ?: selected?.availableStock ?: 0

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("مبيعة خارجية") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(query, { query = it }, label = { Text("ابحث عن المنتج") }, singleLine = true)
                if (selected == null) {
                    LazyColumn(Modifier.heightIn(max = 150.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        items(filtered, key = { it.id }) { product ->
                            TextButton(onClick = { selected = product; salePrice = product.price.toString(); query = product.name }) {
                                Text("${product.name} · مخزون ${product.availableStock}", maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                        }
                    }
                } else {
                    Text("المنتج: ${selected!!.name}", style = MaterialTheme.typography.titleSmall)
                    if (selected!!.sizes.isNotEmpty()) OutlinedTextField(size, { size = it }, label = { Text("المقاس (اختياري)") }, singleLine = true)
                    if (selected!!.colors.isNotEmpty()) OutlinedTextField(color, { color = it }, label = { Text("اللون (اختياري)") }, singleLine = true)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(quantity, { quantity = it }, label = { Text("الكمية") }, singleLine = true, modifier = Modifier.weight(1f))
                        OutlinedTextField(salePrice, { salePrice = it }, label = { Text("سعر البيع") }, singleLine = true, modifier = Modifier.weight(1f))
                    }
                    Text("المخزون المتاح: $selectedStock", style = MaterialTheme.typography.labelSmall)
                    OutlinedTextField(customerName, { customerName = it }, label = { Text("اسم العميل (اختياري)") }, singleLine = true)
                    OutlinedTextField(customerPhone, { customerPhone = it }, label = { Text("هاتف العميل (اختياري)") }, singleLine = true)
                    TextButton(onClick = { selected = null; query = "" }) { Text("تغيير المنتج") }
                }
                if (error.isNotBlank()) Text(error, color = MaterialTheme.colorScheme.error)
            }
        },
        confirmButton = {
            Button(
                enabled = !saving && selected != null,
                onClick = {
                    val product = selected ?: return@Button
                    val count = quantity.toIntOrNull() ?: 0
                    val price = salePrice.toDoubleOrNull() ?: 0.0
                    if (count < 1 || price <= 0 || count > selectedStock) {
                        error = "تحقق من الكمية والسعر والمخزون"
                        return@Button
                    }
                    saving = true
                    scope.launch {
                        runCatching { repository.createExternalSale(product.id, count, price, size, color, customerName, customerPhone) }
                            .onSuccess { onSaved() }
                            .onFailure { error = it.message ?: "تعذر حفظ المبيعة" }
                        saving = false
                    }
                },
            ) { Text(if (saving) "جاري الحفظ..." else "حفظ المبيعة") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("إلغاء") } },
    )
}

@Composable
private fun OrderCard(
    order: Order,
    baseUrl: String,
    busy: Boolean,
    onStatus: (String) -> Unit,
    onDispatch: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val shortId = order.orderId.takeLast(6)
    val date = remember(order.createdAtMs) {
        if (order.createdAtMs <= 0) "" else
            SimpleDateFormat("dd/MM/yyyy · hh:mm a", Locale("ar")).format(Date(order.createdAtMs))
    }

    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("#$shortId", style = MaterialTheme.typography.titleMedium)
                    Text(date, style = MaterialTheme.typography.labelSmall)
                }
                AssistChip(
                    onClick = { expanded = !expanded },
                    label = { Text(OrderStatuses.label(order.status)) },
                )
            }

            Text(
                order.customerName.ifBlank { "بدون اسم" },
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                "${order.customerPhone} · ${order.city}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                "${order.itemsCount} قطعة · ${"%.2f".format(order.grandTotal)} د.ل",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary,
            )

            if (order.ambassadorSummary.isAmbassadorOrder && order.ambassadorSummary.ambassadorName.isNotBlank()) {
                Text(
                    "مندوب: ${order.ambassadorSummary.ambassadorName}",
                    style = MaterialTheme.typography.labelSmall,
                )
            }

            if (order.externalDelivery.trackingNumber.isNotBlank() ||
                order.externalDelivery.referenceCode.isNotBlank()
            ) {
                val clipboard = LocalClipboardManager.current
                val code = order.externalDelivery.referenceCode
                    .ifBlank { order.externalDelivery.trackingNumber }
                Card(
                    Modifier
                        .fillMaxWidth()
                        .clickable { clipboard.setText(AnnotatedString(code)) },
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.secondaryContainer,
                    ),
                ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(Icons.Default.LocalShipping, null, Modifier.size(18.dp))
                        Column(Modifier.weight(1f)) {
                            Text("كود شحنة درب السبيل", style = MaterialTheme.typography.labelSmall)
                            Text(code, style = MaterialTheme.typography.titleSmall)
                            if (order.externalDelivery.trackingNumber.isNotBlank() &&
                                order.externalDelivery.trackingNumber != code
                            ) {
                                Text(
                                    "رقم التتبع: ${order.externalDelivery.trackingNumber}",
                                    style = MaterialTheme.typography.labelSmall,
                                )
                            }
                            if (order.externalDelivery.providerStatus.isNotBlank()) {
                                Text(
                                    "حالة الشركة: ${order.externalDelivery.providerStatus}",
                                    style = MaterialTheme.typography.labelSmall,
                                )
                            }
                        }
                        Icon(Icons.Default.ContentCopy, "نسخ", Modifier.size(16.dp))
                    }
                }
            }
            if (order.externalDelivery.lastError.isNotBlank()) {
                Text(
                    order.externalDelivery.lastError,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }

            if (expanded) {
                order.payload.items.forEach { line ->
                    Row(
                        Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        val imageUrl = if (line.imageUrl.isBlank()) "" else if (line.imageUrl.startsWith("http")) line.imageUrl else baseUrl + (if (line.imageUrl.startsWith("/")) line.imageUrl else "/${line.imageUrl}")
                        if (imageUrl.isNotBlank()) {
                            AsyncImage(
                                model = imageUrl,
                                contentDescription = line.name,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .size(width = 40.dp, height = 50.dp)
                                    .clip(RoundedCornerShape(6.dp)),
                            )
                        }
                        val sizeSuffix = if (line.size.isNotBlank()) " · مقاس ${line.size}" else ""
                        Text(
                            "${line.name}$sizeSuffix ×${line.quantity}",
                            style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
                if (order.customerAddress.isNotBlank()) {
                    Text(order.customerAddress, style = MaterialTheme.typography.labelSmall)
                }

                Text("تغيير الحالة", style = MaterialTheme.typography.labelMedium)
                Row(
                    Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    OrderStatuses.all.forEach { (key, label) ->
                        FilterChip(
                            selected = order.status == key,
                            enabled = !busy && order.status != key,
                            onClick = { onStatus(key) },
                            label = { Text(label) },
                        )
                    }
                }

                if (order.externalDelivery.shipmentId.isBlank()) {
                    OutlinedButton(onClick = onDispatch, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                        if (busy) CircularProgressIndicator(Modifier.size(18.dp))
                        else Text("إرسال لدرب السبيل")
                    }
                }
            }
        }
    }
}
