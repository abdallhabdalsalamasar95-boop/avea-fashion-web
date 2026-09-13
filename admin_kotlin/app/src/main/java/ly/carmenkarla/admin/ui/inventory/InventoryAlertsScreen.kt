package ly.carmenkarla.admin.ui.inventory

import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.Product
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox

private enum class StockFilter(val label: String) {
    OutOfStock("نفد المخزون"),
    Low("على وشك النفاد"),
    Healthy("متوفر"),
}

/** Threshold used when a product has no explicit lowStockThreshold. */
private const val LOW_STOCK_PIECES = 3

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InventoryAlertsScreen(onBack: () -> Unit, onOpenProduct: (String) -> Unit) {
    val repository = AdminApp.instance.repository
    var products by remember { mutableStateOf<List<Product>?>(null) }
    var error by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var filter by remember { mutableStateOf(StockFilter.OutOfStock) }

    LaunchedEffect(reload) {
        error = ""
        products = null
        runCatching { repository.products() }
            .onSuccess { products = it }
            .onFailure { error = it.message ?: "تعذر تحميل المنتجات" }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("تنبيهات المخزون") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "رجوع") }
                },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding)) {
            when {
                error.isNotEmpty() -> ErrorBox(error, { reload++ })
                products == null -> LoadingBox()
                else -> {
                    val all = products!!
                    fun bucket(product: Product): StockFilter = when {
                        product.outOfStock == 1 || product.availableStock <= 0 -> StockFilter.OutOfStock
                        product.availableStock <= LOW_STOCK_PIECES -> StockFilter.Low
                        else -> StockFilter.Healthy
                    }
                    val shown = all.filter { bucket(it) == filter }
                        .sortedBy { it.availableStock }

                    Row(
                        Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState())
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        StockFilter.entries.forEach { entry ->
                            val count = all.count { bucket(it) == entry }
                            FilterChip(
                                selected = filter == entry,
                                onClick = { filter = entry },
                                label = { Text("${entry.label} ($count)") },
                            )
                        }
                    }

                    if (shown.isEmpty()) {
                        Column(
                            Modifier.fillMaxSize(),
                            verticalArrangement = Arrangement.Center,
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(Icons.Default.Inventory2, null, Modifier.size(40.dp))
                            Spacer(Modifier.size(8.dp))
                            Text("لا توجد منتجات في هذا التصنيف")
                        }
                        return@Column
                    }

                    LazyColumn(
                        Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(shown, key = { it.id }) { product ->
                            StockRow(product, filter) { onOpenProduct(product.id) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StockRow(product: Product, filter: StockFilter, onClick: () -> Unit) {
    val tone = when (filter) {
        StockFilter.OutOfStock -> MaterialTheme.colorScheme.errorContainer
        StockFilter.Low -> MaterialTheme.colorScheme.secondaryContainer
        StockFilter.Healthy -> MaterialTheme.colorScheme.surface
    }
    Card(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = tone),
    ) {
        Row(
            Modifier.padding(10.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AsyncImage(
                model = product.imageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(width = 48.dp, height = 60.dp)
                    .clip(RoundedCornerShape(6.dp)),
            )
            Column(Modifier.weight(1f)) {
                Text(
                    product.name,
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    product.category.ifBlank { "غير مصنف" },
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                val perSize = product.sizeQuantities.entries
                    .filter { it.value <= LOW_STOCK_PIECES }
                    .joinToString("  ") { "${it.key}:${it.value}" }
                if (perSize.isNotEmpty()) {
                    Text(perSize, style = MaterialTheme.typography.labelSmall)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text("${product.availableStock}", style = MaterialTheme.typography.titleMedium)
                Text("قطعة", style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}
