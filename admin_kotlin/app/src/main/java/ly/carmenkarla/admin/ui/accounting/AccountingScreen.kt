package ly.carmenkarla.admin.ui.accounting

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.AccountingSummary
import ly.carmenkarla.admin.data.EXPENSE_CATEGORIES
import ly.carmenkarla.admin.data.Expense
import ly.carmenkarla.admin.data.Order
import ly.carmenkarla.admin.data.Product
import ly.carmenkarla.admin.data.TopProduct
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox
import java.util.Locale

@Composable
fun AccountingScreen() {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()

    var summary by remember { mutableStateOf<AccountingSummary?>(null) }
    var expenses by remember { mutableStateOf<List<Expense>>(emptyList()) }
    var error by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var topProductInsights by remember { mutableStateOf<List<TopProductInsight>>(emptyList()) }
    var topCityInsights by remember { mutableStateOf<List<TopCityInsight>>(emptyList()) }

    var amount by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("other") }
    var saving by remember { mutableStateOf(false) }
    var periodDays by remember { mutableStateOf(0) }

    LaunchedEffect(reload, periodDays) {
        error = ""
        summary = null
        topProductInsights = emptyList()
        topCityInsights = emptyList()
        val fromMs = if (periodDays <= 0) 0L else System.currentTimeMillis() - periodDays * 24L * 60L * 60L * 1000L
        runCatching { repository.accounting(fromMs) to repository.expenses() }
            .onSuccess {
                summary = it.first
                expenses = it.second
                runCatching {
                    val products = repository.products()
                    val deliveredOrders = repository.orders()
                        .asSequence()
                        .filter { order -> order.status == "delivered" }
                        .filter { order -> fromMs <= 0 || order.createdAtMs >= fromMs }
                        .toList()
                    topProductInsights = buildTopProductInsights(repository, it.first.topProducts, products, deliveredOrders)
                    topCityInsights = buildTopCityInsights(deliveredOrders)
                }
            }
            .onFailure { error = it.message ?: "تعذر تحميل الحسابات" }
    }

    when {
        error.isNotEmpty() -> ErrorBox(error, { reload++ })
        summary == null -> LoadingBox()
        else -> {
            val data = summary!!
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                item {
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.38f)),
                    ) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text("لوحة الربحية", style = MaterialTheme.typography.titleMedium)
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                MiniMetric("صافي الربح", money2(data.netProfit))
                                MiniMetric("الإيراد", money2(data.revenue))
                                MiniMetric("المصاريف", money2(data.expenses))
                            }
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                MiniMetric("الرصيد المتاح", money2(data.availableAmbassadorBalance))
                                MiniMetric("محجوز سحب", money2(data.reservedWithdrawalBalance))
                                MiniMetric("طلبات موصلة", data.deliveredOrders.toString())
                            }
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
                        listOf(0 to "كل المدة", 1 to "اليوم", 7 to "الأسبوع", 30 to "هذا الشهر", 90 to "3 أشهر").forEach { (days, label) ->
                            FilterChip(
                                selected = periodDays == days,
                                onClick = { periodDays = days },
                                label = { Text(label) },
                            )
                        }
                    }
                }

                item {
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.52f)),
                    ) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("ملخص الأرباح", style = MaterialTheme.typography.titleMedium)
                            MoneyRow("الإيرادات", data.revenue)
                            MoneyRow("تكلفة البضاعة", data.costOfGoods)
                            MoneyRow("الربح الإجمالي", data.grossProfit)
                            MoneyRow("العمولات المعتمدة", data.ambassadorCommissions)
                            MoneyRow("المصاريف", data.expenses)
                            MoneyRow("صافي الربح", data.netProfit, highlight = true)
                            Text(
                                "${data.deliveredOrders} طلب موصّل · ${data.soldPieces} قطعة مباعة · ${data.ambassadorCount} مندوبة نشطة",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }

                item {
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.42f)),
                    ) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("تفكيك عمولات المندوبات", style = MaterialTheme.typography.titleMedium)
                            MoneyRow("العمولات المعتمدة", data.approvedAmbassadorCommissions)
                            MoneyRow("بانتظار الاعتماد", data.pendingAmbassadorCommissions)
                            MoneyRow("عمولات جارية", data.pipelineAmbassadorCommissions)
                            MoneyRow("الرصيد القابل للسحب", data.availableAmbassadorBalance, highlight = true)
                            MoneyRow("الرصيد المحجوز للسحب", data.reservedWithdrawalBalance)
                        }
                    }
                }

                item {
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.42f)),
                    ) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("المخزون", style = MaterialTheme.typography.titleMedium)
                            MoneyRow("قيمة الشراء", data.inventoryCostValue)
                            MoneyRow("قيمة البيع", data.inventorySaleValue)
                            MoneyRow("الربح المتوقع", data.inventoryPotentialProfit, highlight = true)
                            Text("${data.inventoryPieces} قطعة بالمخزن", style = MaterialTheme.typography.labelSmall)
                            if (data.missingCostProducts > 0) {
                                Text(
                                    "${data.missingCostProducts} منتج بدون سعر شراء و ${data.missingCostSoldPieces} قطعة مباعة ناقصة التكلفة",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.error,
                                )
                            }
                        }
                    }
                }

                if (data.topAmbassadors.isNotEmpty()) {
                    item {
                        Card(
                            Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.34f)),
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("أفضل المندوبات ماليًا", style = MaterialTheme.typography.titleMedium)
                                data.topAmbassadors.take(6).forEach { row ->
                                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                        Column(Modifier.weight(1f)) {
                                            Text(row.displayName, style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                            Text(
                                                "${row.deliveredOrders} موصّل · ${row.ordersCount} طلب",
                                                style = MaterialTheme.typography.labelSmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        }
                                        Text(
                                            money2(row.approvedCommission),
                                            style = MaterialTheme.typography.labelMedium,
                                            color = MaterialTheme.colorScheme.primary,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                if (data.topProducts.isNotEmpty()) {
                    item {
                        Card(
                            Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.34f)),
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text("الأكثر مبيعًا", style = MaterialTheme.typography.titleMedium)
                                (topProductInsights.ifEmpty { data.topProducts.take(8).map { TopProductInsight.fromFallback(it) } }).forEach { row ->
                                    TopProductRow(row)
                                }
                            }
                        }
                    }
                }

                if (topCityInsights.isNotEmpty()) {
                    item {
                        Card(
                            Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.3f)),
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("أكثر المدن شراءً", style = MaterialTheme.typography.titleMedium)
                                topCityInsights.take(8).forEach { city ->
                                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                        Column(Modifier.weight(1f)) {
                                            Text(city.city, style = MaterialTheme.typography.labelMedium)
                                            Text(
                                                "${city.orders} طلب موصّل · ${city.pieces} قطعة",
                                                style = MaterialTheme.typography.labelSmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        }
                                        Text(
                                            money2(city.revenue),
                                            style = MaterialTheme.typography.labelMedium,
                                            color = MaterialTheme.colorScheme.primary,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                item {
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.32f)),
                    ) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text("إضافة مصروف", style = MaterialTheme.typography.titleMedium)
                            OutlinedTextField(
                                value = amount,
                                onValueChange = { amount = it },
                                label = { Text("المبلغ") },
                                singleLine = true,
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                                modifier = Modifier.fillMaxWidth(),
                            )
                            OutlinedTextField(
                                value = description,
                                onValueChange = { description = it },
                                label = { Text("الوصف") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                            )
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                EXPENSE_CATEGORIES.forEach { (key, label) ->
                                    FilterChip(
                                        selected = category == key,
                                        onClick = { category = key },
                                        label = { Text(label) },
                                    )
                                }
                            }
                            if (message.isNotEmpty()) {
                                Text(
                                    message,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = if (message.contains("✓")) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                                )
                            }
                            Button(
                                onClick = {
                                    val value = amount.replace(',', '.').toDoubleOrNull() ?: 0.0
                                    if (value <= 0 || description.isBlank()) {
                                        message = "أدخلي المبلغ والوصف"
                                        return@Button
                                    }
                                    saving = true
                                    message = ""
                                    scope.launch {
                                        runCatching { repository.addExpense(value, category, description.trim()) }
                                            .onSuccess {
                                                amount = ""
                                                description = ""
                                                message = "تمت الإضافة ✓"
                                                reload++
                                            }
                                            .onFailure { message = it.message ?: "تعذر الحفظ" }
                                        saving = false
                                    }
                                },
                                enabled = !saving,
                                modifier = Modifier.fillMaxWidth(),
                            ) { Text("حفظ المصروف") }
                        }
                    }
                }

                item { Text("المصاريف المسجّلة", style = MaterialTheme.typography.titleMedium) }

                if (expenses.isEmpty()) {
                    item { Text("لا توجد مصاريف بعد", style = MaterialTheme.typography.labelMedium) }
                }

                items(expenses, key = { it.id }) { expense ->
                    Card(
                        Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)),
                    ) {
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .padding(start = 14.dp, top = 6.dp, bottom = 6.dp, end = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(expense.description, style = MaterialTheme.typography.bodyMedium)
                                Text(
                                    EXPENSE_CATEGORIES.firstOrNull { it.first == expense.category }?.second ?: expense.category,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Text(money2(expense.amount), style = MaterialTheme.typography.titleSmall)
                            IconButton(onClick = {
                                scope.launch {
                                    runCatching { repository.removeExpense(expense.id) }
                                        .onSuccess { reload++ }
                                        .onFailure { message = it.message ?: "تعذر الحذف" }
                                }
                            }) { Icon(Icons.Default.Delete, "حذف") }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MiniMetric(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun TopProductRow(row: TopProductInsight) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (row.imageUrl.isNotBlank()) {
            AsyncImage(
                model = row.imageUrl,
                contentDescription = row.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(46.dp)
                    .clip(MaterialTheme.shapes.medium),
            )
        } else {
            Box(
                Modifier
                    .size(46.dp)
                    .clip(MaterialTheme.shapes.medium)
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center,
            ) {
                Text("—", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(row.name, style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                "${row.pieces} قطعة · ربح ${String.format(Locale.US, "%.0f", row.profit)} د.ل",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            val meta = listOfNotNull(
                row.topSize?.takeIf { it.isNotBlank() }?.let { "الأشهر: $it" },
                row.topCity?.takeIf { it.isNotBlank() }?.let { "المدينة: $it" },
            ).joinToString("  •  ")
            if (meta.isNotBlank()) {
                Text(meta, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            }
        }
        Spacer(Modifier.size(4.dp))
        Text(money2(row.sales), style = MaterialTheme.typography.labelMedium)
    }
}

private data class TopProductInsight(
    val productId: String,
    val name: String,
    val pieces: Int,
    val sales: Double,
    val profit: Double,
    val imageUrl: String,
    val topSize: String?,
    val topCity: String?,
) {
    companion object {
        fun fromFallback(row: TopProduct) = TopProductInsight(
            productId = row.productId,
            name = row.name.ifBlank { row.productId },
            pieces = row.pieces,
            sales = row.sales,
            profit = row.profit,
            imageUrl = "",
            topSize = null,
            topCity = null,
        )
    }
}

private data class TopCityInsight(
    val city: String,
    val orders: Int,
    val pieces: Int,
    val revenue: Double,
)

private suspend fun buildTopProductInsights(
    repository: ly.carmenkarla.admin.data.Repository,
    rows: List<TopProduct>,
    products: List<Product>,
    deliveredOrders: List<Order>,
): List<TopProductInsight> {
    val byId = products.associateBy { it.id }
    val byName = products.associateBy { it.name.trim().lowercase(Locale.ROOT) }

    data class ProductOrderMeta(
        val sizeCount: MutableMap<String, Int> = linkedMapOf(),
        val cityCount: MutableMap<String, Int> = linkedMapOf(),
    )

    val meta = linkedMapOf<String, ProductOrderMeta>()
    deliveredOrders.forEach { order ->
        val city = order.city.trim().ifBlank { "غير محددة" }
        order.payload.items.forEach { line ->
            val key = line.productId.ifBlank { line.name.trim().lowercase(Locale.ROOT) }
            val bucket = meta.getOrPut(key) { ProductOrderMeta() }
            val size = line.size.trim().ifBlank { "بدون مقاس" }
            bucket.sizeCount[size] = (bucket.sizeCount[size] ?: 0) + line.quantity
            bucket.cityCount[city] = (bucket.cityCount[city] ?: 0) + line.quantity
        }
    }

    suspend fun resolveImage(product: Product?): String {
        val raw = product?.imageUrl?.ifBlank { product.imageUrls.firstOrNull().orEmpty() }.orEmpty()
        return repository.absoluteUrl(raw)
    }

    return rows.take(8).map { row ->
        val lookupKey = row.productId.ifBlank { row.name.trim().lowercase(Locale.ROOT) }
        val product = byId[row.productId] ?: byName[row.name.trim().lowercase(Locale.ROOT)]
        val bucket = meta[lookupKey]
        TopProductInsight(
            productId = row.productId,
            name = row.name.ifBlank { product?.name ?: row.productId },
            pieces = row.pieces,
            sales = row.sales,
            profit = row.profit,
            imageUrl = resolveImage(product),
            topSize = bucket?.sizeCount?.maxByOrNull { it.value }?.key,
            topCity = bucket?.cityCount?.maxByOrNull { it.value }?.key,
        )
    }
}

private fun buildTopCityInsights(deliveredOrders: List<Order>): List<TopCityInsight> =
    deliveredOrders
        .groupBy { it.city.trim().ifBlank { "غير محددة" } }
        .map { (city, orders) ->
            TopCityInsight(
                city = city,
                orders = orders.size,
                pieces = orders.sumOf { it.itemsCount },
                revenue = orders.sumOf { it.grandTotal },
            )
        }
        .sortedByDescending { it.revenue }

@Composable
private fun MoneyRow(label: String, value: Double, highlight: Boolean = false) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(
            money2(value),
            style = if (highlight) MaterialTheme.typography.titleMedium else MaterialTheme.typography.bodyMedium,
            color = when {
                highlight && value >= 0 -> MaterialTheme.colorScheme.primary
                value < 0 -> MaterialTheme.colorScheme.error
                else -> MaterialTheme.colorScheme.onSurface
            },
        )
    }
}

private fun money2(value: Double): String = String.format(Locale.US, "%.2f د.ل", value)
