package ly.carmenkarla.admin.ui.products

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.Product
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox

@Composable
fun ProductsScreen(onOpenEditor: (String?) -> Unit, refreshKey: Int) {
    val repository = AdminApp.instance.repository
    var products by remember { mutableStateOf<List<Product>?>(null) }
    var error by remember { mutableStateOf("") }
    var query by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var baseUrl by remember { mutableStateOf("") }

    LaunchedEffect(reload, refreshKey) {
        error = ""
        products = null
        baseUrl = repository.settings.currentBaseUrl().trimEnd('/')
        runCatching { repository.products() }
            .onSuccess { products = it }
            .onFailure { error = it.message ?: "تعذر تحميل المنتجات" }
    }

    Scaffold(
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { onOpenEditor(null) },
                icon = { Icon(Icons.Default.Add, null) },
                text = { Text("منتج جديد") },
            )
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when {
                error.isNotEmpty() -> ErrorBox(error, { reload++ })
                products == null -> LoadingBox()
                else -> {
                    val filtered = products!!.filter {
                        query.isBlank() ||
                            it.name.contains(query, true) ||
                            it.productCode.contains(query, true) ||
                            it.category.contains(query, true)
                    }
                    Column(Modifier.fillMaxSize()) {
                        OutlinedTextField(
                            value = query,
                            onValueChange = { query = it },
                            placeholder = { Text("ابحث بالاسم أو الرمز") },
                            leadingIcon = { Icon(Icons.Default.Search, null) },
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 10.dp),
                        )
                        Text(
                            "${filtered.size} منتج",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 18.dp, vertical = 4.dp),
                        )
                        LazyColumn(
                            Modifier.fillMaxSize(),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                                start = 16.dp, end = 16.dp, bottom = 96.dp, top = 4.dp,
                            ),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            items(filtered, key = { it.id }) { product ->
                                ProductRow(product, baseUrl) { onOpenEditor(product.id) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProductRow(product: Product, baseUrl: String, onClick: () -> Unit) {
    val image = product.imageUrl.ifBlank { product.imageUrls.firstOrNull().orEmpty() }
    val fullUrl = when {
        image.isBlank() -> ""
        image.startsWith("http") -> image
        image.startsWith("/") -> baseUrl + image
        else -> "$baseUrl/$image"
    }
    val stock = product.sizeQuantities.values.sum().takeIf { it > 0 } ?: product.availableStock

    Card(Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
            AsyncImage(
                model = fullUrl,
                contentDescription = product.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(width = 58.dp, height = 72.dp)
                    .clip(RoundedCornerShape(8.dp)),
            )
            Column(
                Modifier
                    .weight(1f)
                    .padding(horizontal = 12.dp),
            ) {
                Text(
                    product.name.ifBlank { "بدون اسم" },
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    product.productCode,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    "${product.price.toInt()} د.ل  •  المخزون $stock",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            if (product.isHidden == 1) {
                Text(
                    "مخفي",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}
