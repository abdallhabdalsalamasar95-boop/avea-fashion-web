package ly.carmenkarla.shop.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.BasicAlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.HomeCategory
import ly.carmenkarla.shop.data.Product
import ly.carmenkarla.shop.data.WebsiteHome
import ly.carmenkarla.shop.ui.CatalogSkeleton
import ly.carmenkarla.shop.ui.ErrorBox
import ly.carmenkarla.shop.ui.ProductCard
import ly.carmenkarla.shop.ui.ProductImage
import ly.carmenkarla.shop.ui.theme.Brand

private const val PAD = 12

@Composable
fun HomeScreen(
    onOpenProduct: (String) -> Unit,
    onOpenAmbassador: () -> Unit,
    onOpenWholesale: () -> Unit,
) {
    val app = ShopApp.instance

    var products by remember { mutableStateOf<List<Product>?>(null) }
    var home by remember { mutableStateOf(WebsiteHome()) }
    var error by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var query by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("") }

    LaunchedEffect(reload) {
        error = ""
        products = null
        runCatching { app.repository.products() to app.repository.homeContent() }
            .onSuccess {
                products = it.first
                home = it.second
            }
            .onFailure { error = it.message ?: "تعذر تحميل المتجر" }
    }

    when {
        error.isNotEmpty() -> ErrorBox(error, { reload++ })
        products == null -> CatalogSkeleton()
        else -> {
            val all = products!!
            val browsing = query.isBlank() && category.isEmpty()
            val shown = all.filter { product ->
                (category.isEmpty() || product.category.trim() == category) &&
                    (query.isBlank() || product.name.contains(query.trim(), ignoreCase = true))
            }
            val newest = remember(all) { all.sortedByDescending { it.createdAt }.take(8) }
            val bestSellers = remember(all) {
                all.filter { it.soldPieces > 0 }.sortedByDescending { it.soldPieces }.take(8)
            }
            val tiles = remember(all, home) {
                home.categories.filter { it.enabled && it.title.isNotBlank() }.ifEmpty {
                    all.map { it.category.trim() }.filter { it.isNotEmpty() }.distinct().sorted()
                        .map { HomeCategory(id = it, title = it, productCategoryFilter = it) }
                }
            }

            Column(Modifier.fillMaxSize()) {
                SearchBar(query, { query = it }) { query = "" }

                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 24.dp),
                    horizontalArrangement = Arrangement.spacedBy(PAD.dp),
                    verticalArrangement = Arrangement.spacedBy(PAD.dp),
                ) {
                    if (browsing) {
                        if (home.banner.enabled && home.banner.imageUrl.isNotBlank()) {
                            span { Banner(home.banner.imageUrl) }
                        }
                        if (tiles.isNotEmpty()) {
                            span { CategoryTiles(tiles) { category = it } }
                        }
                        if (newest.isNotEmpty()) {
                            span { SectionTitle("وصل حديثًا") }
                            span { Rail(newest, onOpenProduct) }
                        }
                        if (home.sectionBanner.enabled && home.sectionBanner.imageUrl.isNotBlank()) {
                            span { Banner(home.sectionBanner.imageUrl) }
                        }
                        if (bestSellers.isNotEmpty()) {
                            span { SectionTitle("الأكثر مبيعًا") }
                            span { Rail(bestSellers, onOpenProduct) }
                        }
                        if (app.wholesale.enabled && all.any { it.hasWholesale }) {
                            span { WholesaleStrip(onOpenWholesale) }
                        }
                        span { AmbassadorStrip(onOpenAmbassador) }
                    }

                    span {
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .padding(horizontal = PAD.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                if (category.isNotEmpty()) category else "كل المنتجات",
                                style = MaterialTheme.typography.titleLarge,
                            )
                            if (!browsing) {
                                Text(
                                    "عرض الكل",
                                    Modifier.clickable {
                                        category = ""
                                        query = ""
                                    },
                                    style = MaterialTheme.typography.labelMedium,
                                    color = Brand.Rose,
                                )
                            } else {
                                Text(
                                    "${shown.size} قطعة",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }

                    if (shown.isEmpty()) {
                        span {
                            Box(
                                Modifier
                                    .fillMaxWidth()
                                    .height(140.dp),
                                contentAlignment = Alignment.Center,
                            ) { Text("لا توجد نتائج", style = MaterialTheme.typography.bodyMedium) }
                        }
                    }

                    itemsIndexed(shown, key = { _, item -> item.id }) { index, product ->
                        ProductCard(
                            product = product,
                            modifier = Modifier.padding(
                                start = if (index % 2 == 0) PAD.dp else 0.dp,
                                end = if (index % 2 == 0) 0.dp else PAD.dp,
                            ),
                        ) { onOpenProduct(product.id) }
                    }
                }
            }
        }
    }
}

private fun LazyGridScope.span(content: @Composable () -> Unit) {
    item(span = { GridItemSpan(2) }) { content() }
}

@Composable
private fun SearchBar(query: String, onChange: (String) -> Unit, onClear: () -> Unit) {
    Column(Modifier.background(MaterialTheme.colorScheme.surface)) {
        TextField(
            value = query,
            onValueChange = onChange,
            placeholder = {
                Text(
                    "ادخل كلمة البحث",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Brand.Muted,
                )
            },
            trailingIcon = {
                if (query.isEmpty()) {
                    Icon(Icons.Outlined.Search, null, Modifier.size(20.dp), tint = Brand.Muted)
                } else {
                    Icon(
                        Icons.Default.Close,
                        "مسح",
                        Modifier
                            .size(20.dp)
                            .clickable(onClick = onClear),
                        tint = Brand.Ink,
                    )
                }
            },
            singleLine = true,
            colors = TextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surface,
                unfocusedContainerColor = MaterialTheme.colorScheme.surface,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        Box(
            Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(MaterialTheme.colorScheme.outline),
        )
    }
}

@Composable
private fun Banner(imageUrl: String) {
    ProductImage(
        imageUrl,
        Modifier
            .fillMaxWidth()
            .aspectRatio(1.9f),
    )
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        title,
        Modifier
            .fillMaxWidth()
            .padding(horizontal = PAD.dp),
        style = MaterialTheme.typography.titleLarge,
        textAlign = TextAlign.Start,
    )
}

@Composable
private fun CategoryTiles(categories: List<HomeCategory>, onPick: (String) -> Unit) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = PAD.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        items(categories, key = { it.id }) { entry ->
            val name = entry.productCategoryFilter.ifBlank { entry.title }
            Column(
                Modifier
                    .width(62.dp)
                    .clickable { onPick(name) },
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                ProductImage(
                    entry.imageUrl,
                    Modifier
                        .size(52.dp)
                        .clip(CircleShape)
                        .border(1.dp, MaterialTheme.colorScheme.outline, CircleShape),
                )
                Spacer(Modifier.height(5.dp))
                Text(
                    entry.title,
                    style = MaterialTheme.typography.labelSmall,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun Rail(items: List<Product>, onOpen: (String) -> Unit) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = PAD.dp),
        horizontalArrangement = Arrangement.spacedBy(PAD.dp),
    ) {
        items(items, key = { it.id }) { product ->
            ProductCard(product, Modifier.width(168.dp)) { onOpen(product.id) }
        }
    }
}

@Composable
private fun WholesaleStrip(onOpen: () -> Unit) {
    val settings = ShopApp.instance.wholesale
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = PAD.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Brand.RoseSoft)
            .border(1.dp, Brand.Rose.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
            .clickable(onClick = onOpen)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                settings.title.ifBlank { "قسم الجملة" },
                style = MaterialTheme.typography.titleSmall,
                color = Brand.RoseDark,
            )
            Text(
                settings.subtitle.ifBlank { "أسعار خاصة عند شراء الكمية" },
                style = MaterialTheme.typography.labelSmall,
                color = Brand.RoseDark.copy(alpha = 0.75f),
            )
        }
        Text(
            "تصفّحي",
            Modifier
                .background(Brand.RoseDark, RoundedCornerShape(6.dp))
                .padding(horizontal = 14.dp, vertical = 6.dp),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            color = Color.White,
        )
    }
}

@Composable
private fun AmbassadorStrip(onOpen: () -> Unit) {
    val joined = ShopApp.instance.ambassador != null
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = PAD.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Brand.Ink)
            .clickable(onClick = onOpen)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                if (joined) "لوحة المندوبة" else "كوني مندوبة كارمن كارلا",
                style = MaterialTheme.typography.titleSmall,
                color = Color.White,
            )
            Text(
                if (joined) "تابعي أرباحك وطلبات عميلاتك"
                else "اربحي عمولة على كل طلب بدون رأس مال",
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.7f),
            )
        }
        Text(
            if (joined) "افتحي" else "انضمي",
            Modifier
                .background(Brand.Gold, RoundedCornerShape(6.dp))
                .padding(horizontal = 14.dp, vertical = 6.dp),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            color = Brand.Ink,
        )
    }
}
