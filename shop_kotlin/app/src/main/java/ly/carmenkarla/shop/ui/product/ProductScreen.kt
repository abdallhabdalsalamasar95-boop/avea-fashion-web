package ly.carmenkarla.shop.ui.product

import android.content.Intent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.absoluteOffset
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.shop.CartAddResult
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.CartLine
import ly.carmenkarla.shop.data.Product
import ly.carmenkarla.shop.ui.ErrorBox
import ly.carmenkarla.shop.ui.LoadingBox
import ly.carmenkarla.shop.ui.ProductCard
import ly.carmenkarla.shop.ui.ProductImage
import ly.carmenkarla.shop.ui.formatMoney
import ly.carmenkarla.shop.ui.theme.Brand

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ProductScreen(
    productId: String,
    onBack: () -> Unit,
    onOpenCart: () -> Unit,
    onBuyNow: () -> Unit,
    onOpenRelated: (String) -> Unit,
) {
    val app = ShopApp.instance
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var product by remember { mutableStateOf<Product?>(null) }
    var related by remember { mutableStateOf<List<Product>>(emptyList()) }
    var error by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var sharing by remember { mutableStateOf(false) }

    var size by remember { mutableStateOf("") }
    var color by remember { mutableStateOf("") }
    var quantity by remember { mutableStateOf(1) }
    var added by remember { mutableStateOf(false) }
    var stockWarning by remember { mutableStateOf("") }
    val scrollState = rememberScrollState()

    var cartAnchor by remember { mutableStateOf(Offset.Zero) }
    var imageAnchor by remember { mutableStateOf(Offset.Zero) }
    var flightStart by remember { mutableStateOf(Offset.Zero) }
    var flightImage by remember { mutableStateOf("") }
    var flightKey by remember { mutableStateOf(0) }
    val flight = remember { Animatable(0f) }

    LaunchedEffect(flightKey) {
        if (flightKey == 0) return@LaunchedEffect
        flight.snapTo(0f)
        flight.animateTo(1f, tween(680))
    }

    LaunchedEffect(productId, reload) {
        error = ""
        product = null
        size = ""
        color = ""
        quantity = 1
        added = false
        scrollState.scrollTo(0)
        runCatching { app.repository.products() }
            .onSuccess { catalog ->
                val found = catalog.firstOrNull { it.id == productId }
                product = found
                if (found == null) error = "المنتج غير موجود"
                if (found != null && found.availableSizes.size == 1) size = found.availableSizes.first()
                if (found != null && found.colors.size == 1) color = found.colors.first()
                related = if (found == null) emptyList() else catalog
                    .filter { it.id != found.id && it.category.trim() == found.category.trim() }
                    .take(10)
                    .ifEmpty { catalog.filter { it.id != found.id }.take(10) }
            }
            .onFailure { error = it.message ?: "تعذر تحميل المنتج" }
    }

    Box(Modifier.fillMaxSize()) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("تفاصيل القطعة") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "رجوع") } },
                actions = {
                    BadgedBox(
                        badge = {
                            if (app.cartCount > 0) {
                                Badge(containerColor = Brand.Rose) { Text(app.cartCount.toString()) }
                            }
                        },
                        modifier = Modifier.onGloballyPositioned { cartAnchor = it.boundsInRoot().center },
                    ) {
                        IconButton(onClick = onOpenCart) {
                            Icon(Icons.Outlined.ShoppingCart, "السلة")
                        }
                    }
                    IconButton(onClick = { app.toggleFavorite(productId) }) {
                        Icon(
                            if (app.isFavorite(productId)) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                            "المفضلة",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                },
            )
        },
    ) { padding ->
        when {
            error.isNotEmpty() -> Box(Modifier.padding(padding)) { ErrorBox(error, { reload++ }) }
            product == null -> Box(Modifier.padding(padding)) { LoadingBox() }
            else -> {
                val item = product!!
                val inCart = app.cart.filter { it.productId == item.id && it.size == size && it.color == color }
                    .sumOf { it.quantity }
                val stockLeft = item.stockFor(size)
                val maxQuantity = (stockLeft - inCart).coerceAtLeast(0)
                val missingOptions = (item.availableSizes.isNotEmpty() && size.isBlank()) ||
                    (item.colors.isNotEmpty() && color.isBlank())

                Box(Modifier.padding(padding)) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .verticalScroll(scrollState),
                ) {
                    val gallery = item.gallery
                    if (gallery.isNotEmpty()) {
                        val pagerState = rememberPagerState { gallery.size }
                        Box {
                            HorizontalPager(
                                state = pagerState,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .aspectRatio(0.8f)
                                    .onGloballyPositioned { imageAnchor = it.boundsInRoot().center },
                            ) { page ->
                                ProductImage(gallery[page], Modifier.fillMaxSize())
                            }
                            if (gallery.size > 1) {
                                Row(
                                    Modifier
                                        .align(Alignment.BottomCenter)
                                        .padding(bottom = 12.dp),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                ) {
                                    repeat(gallery.size) { index ->
                                        val active = pagerState.currentPage == index
                                        Box(
                                            Modifier
                                                .size(width = if (active) 18.dp else 6.dp, height = 6.dp)
                                                .clip(RoundedCornerShape(3.dp))
                                                .background(
                                                    if (active) Brand.Ink
                                                    else Brand.Ink.copy(alpha = 0.25f),
                                                ),
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Column(
                        Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Text(item.category, style = MaterialTheme.typography.labelMedium)
                        Text(item.name, style = MaterialTheme.typography.headlineSmall)

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(
                                formatMoney(item.price),
                                style = MaterialTheme.typography.headlineSmall,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            if (item.oldPrice > item.price) {
                                Text(
                                    formatMoney(item.oldPrice),
                                    style = MaterialTheme.typography.bodyMedium,
                                    textDecoration = TextDecoration.LineThrough,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }

                        if (item.description.isNotBlank()) {
                            Text(item.description, style = MaterialTheme.typography.bodyMedium)
                        }

                        val ambassador = app.ambassador
                        if (ambassador != null) {
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(14.dp))
                                    .border(
                                        1.dp,
                                        MaterialTheme.colorScheme.secondary.copy(alpha = 0.55f),
                                        RoundedCornerShape(14.dp),
                                    )
                                    .padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text(
                                        "عمولتك على القطعة",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                    Text(
                                        formatMoney(app.commission.amountFor(item)),
                                        style = MaterialTheme.typography.titleLarge,
                                        color = MaterialTheme.colorScheme.secondary,
                                    )
                                }
                                Text(
                                    "${app.commission.rateFor(item).toInt()}%",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.secondary,
                                )
                            }
                        }

                        OutlinedButton(
                            onClick = {
                                sharing = true
                                scope.launch {
                                    val token = if (ambassador == null) "" else {
                                        app.repository.shareToken(app.account.idToken())
                                    }
                                    val link = app.repository.productLink(item.id, token)
                                    val text = if (ambassador == null) {
                                        "شاهدي ${item.name} على متجر Carmen Karla."
                                    } else {
                                        "اختيار خاص لكِ من شريكة Carmen Karla المعتمدة ${ambassador.ambassadorName}. " +
                                            "راجعي ${item.name} وأكملي طلبك بسهولة."
                                    }
                                    val intent = Intent(Intent.ACTION_SEND).apply {
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_TEXT, "$text\n$link")
                                    }
                                    context.startActivity(Intent.createChooser(intent, "مشاركة عبر"))
                                    sharing = false
                                }
                            },
                            enabled = !sharing,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Icon(Icons.Default.Share, null, Modifier.size(18.dp))
                            Text(
                                if (ambassador != null) "  شاركي مع عميلاتك" else "  مشاركة المنتج",
                            )
                        }

                        if (item.availableSizes.isNotEmpty()) {
                            Text("المقاس", style = MaterialTheme.typography.labelLarge)
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                item.availableSizes.forEach { option ->
                                    FilterChip(
                                        selected = size == option,
                                        onClick = {
                                            size = option
                                            quantity = 1
                                        },
                                        label = { Text(option) },
                                    )
                                }
                            }
                            if (size.isNotBlank() && stockLeft in 1..3) {
                                Text(
                                    "متبقي $stockLeft فقط من هذا المقاس",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.error,
                                )
                            }
                            SizeFinder(item.availableSizes) { size = it }
                        } else if (item.sizes.isNotEmpty()) {
                            Text(
                                "هذا الموديل غير متوفر حاليًا",
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }

                        if (item.colors.isNotEmpty()) {
                            Text("اللون", style = MaterialTheme.typography.labelLarge)
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                item.colors.forEach { option ->
                                    FilterChip(
                                        selected = color == option,
                                        onClick = { color = option },
                                        label = { Text(option) },
                                    )
                                }
                            }
                        }

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Text("الكمية", style = MaterialTheme.typography.labelLarge)
                            OutlinedButton(
                                onClick = { quantity = (quantity - 1).coerceAtLeast(1) },
                                enabled = quantity > 1,
                            ) { Text("−") }
                            Text(quantity.toString(), style = MaterialTheme.typography.titleMedium)
                            OutlinedButton(
                                onClick = {
                                    if (quantity >= maxQuantity) {
                                        stockWarning = outOfStockMessage(item, size, color, stockLeft)
                                    } else {
                                        quantity++
                                        stockWarning = ""
                                    }
                                },
                                enabled = !missingOptions,
                            ) { Text("+") }
                            if (!missingOptions && maxQuantity in 1..5) {
                                Text(
                                    "متبقي $maxQuantity فقط",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Brand.Rose,
                                )
                            }
                        }

                        if (item.hasWholesale && app.wholesale.enabled) {
                            val active = quantity >= item.wholesaleThreshold
                            Column(
                                Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(if (active) Brand.RoseSoft else MaterialTheme.colorScheme.surface)
                                    .border(
                                        1.dp,
                                        if (active) Brand.Rose else MaterialTheme.colorScheme.outline,
                                        RoundedCornerShape(12.dp),
                                    )
                                    .padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(4.dp),
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        "سعر الجملة",
                                        style = MaterialTheme.typography.labelLarge,
                                        color = Brand.RoseDark,
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        formatMoney(item.wholesalePrice),
                                        style = MaterialTheme.typography.titleSmall,
                                        color = Brand.RoseDark,
                                    )
                                    Spacer(Modifier.weight(1f))
                                    Text(
                                        "وفّري %${item.wholesaleSavingPercent}",
                                        Modifier
                                            .clip(RoundedCornerShape(6.dp))
                                            .background(Brand.Rose)
                                            .padding(horizontal = 7.dp, vertical = 2.dp),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = androidx.compose.ui.graphics.Color.White,
                                    )
                                }
                                Text(
                                    if (active) "سعر الجملة مفعّل على هذه الكمية ✓"
                                    else "اطلبي ${item.wholesaleThreshold} قطع أو أكثر ليُطبّق تلقائيًا",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = if (active) Brand.RoseDark else Brand.Muted,
                                )
                            }
                        }

                        if (stockWarning.isNotEmpty()) {
                            Surface(
                                color = MaterialTheme.colorScheme.errorContainer,
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text(
                                    stockWarning,
                                    Modifier.padding(12.dp),
                                    style = MaterialTheme.typography.bodySmall,
                                )
                            }
                        }

                        if (item.soldOut) {
                            Surface(
                                color = MaterialTheme.colorScheme.errorContainer,
                                shape = RoundedCornerShape(10.dp),
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text(
                                    "نفدت الكمية حاليًا",
                                    Modifier.padding(12.dp),
                                    style = MaterialTheme.typography.bodyMedium,
                                )
                            }
                        } else {
                            if (missingOptions) {
                                Text(
                                    "اختاري المقاس واللون أولًا",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.error,
                                )
                            }
                            if (added) {
                                OutlinedButton(
                                    onClick = onOpenCart,
                                    modifier = Modifier.fillMaxWidth(),
                                ) { Text("تمت الإضافة ✓ — عرض السلة") }
                            }
                            Spacer(Modifier.height(70.dp))
                        }
                    }

                    if (related.isNotEmpty()) {
                        Text(
                            "منتجات مشابهة",
                            Modifier.padding(start = 16.dp, end = 16.dp, bottom = 10.dp),
                            style = MaterialTheme.typography.titleLarge,
                        )
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            items(related, key = { it.id }) { other ->
                                ProductCard(other, Modifier.width(150.dp)) { onOpenRelated(other.id) }
                            }
                        }
                        Spacer(Modifier.height(80.dp))
                    }
                }

                if (!item.soldOut) {
                    PurchaseBar(
                        total = item.unitPriceFor(quantity) * quantity,
                        enabled = !missingOptions,
                        modifier = Modifier.align(Alignment.BottomCenter),
                        onAdd = { origin ->
                            when (val result = app.addToCart(cartLineFor(item, size, color, quantity, stockLeft))) {
                                is CartAddResult.OutOfStock -> {
                                    stockWarning = outOfStockMessage(item, size, color, result.available)
                                }
                                else -> {
                                    stockWarning = if (result is CartAddResult.Capped) {
                                        "أضفنا المتوفر فقط (${result.available} قطعة) — لا يوجد أكثر في المخزون."
                                    } else {
                                        ""
                                    }
                                    added = true
                                    quantity = 1
                                    flightStart = if (imageAnchor != Offset.Zero) imageAnchor else origin
                                    flightImage = item.gallery.firstOrNull().orEmpty()
                                    flightKey++
                                }
                            }
                        },
                        onBuyNow = {
                            when (val result = app.addToCart(cartLineFor(item, size, color, quantity, stockLeft))) {
                                is CartAddResult.OutOfStock ->
                                    stockWarning = outOfStockMessage(item, size, color, result.available)
                                else -> onBuyNow()
                            }
                        },
                    )
                }
                }
            }
        }
    }

        // Rendered at the composition root so root coordinates land exactly on the cart icon.
        if (flightKey > 0 && flight.value < 1f && cartAnchor != Offset.Zero) {
            val t = flight.value
            val density = LocalDensity.current
            val startSize = 96.dp
            val endSize = 22.dp
            val sizeDp = startSize + (endSize - startSize) * t
            val half = with(density) { sizeDp.toPx() } / 2f
            // Single control point: rises slightly then curves straight into the cart icon.
            val control = Offset(
                flightStart.x + (cartAnchor.x - flightStart.x) * 0.25f,
                flightStart.y - (flightStart.y - cartAnchor.y) * 0.35f,
            )
            val inv = 1f - t
            val x = inv * inv * flightStart.x + 2f * inv * t * control.x + t * t * cartAnchor.x
            val y = inv * inv * flightStart.y + 2f * inv * t * control.y + t * t * cartAnchor.y
            ProductImage(
                flightImage,
                Modifier
                    .align(AbsoluteAlignment.TopLeft)
                    .absoluteOffset { IntOffset((x - half).toInt(), (y - half).toInt()) }
                    .size(sizeDp)
                    .alpha(if (t > 0.85f) (1f - t) / 0.15f else 1f)
                    .clip(RoundedCornerShape(12.dp)),
            )
        }
    }
}

private fun cartLineFor(item: Product, size: String, color: String, quantity: Int, stockLimit: Int) = CartLine(
    lineId = "${item.id}_${size}_$color",
    productId = item.id,
    productCode = item.productCode,
    name = item.name,
    price = item.price,
    imageUrl = item.gallery.firstOrNull().orEmpty(),
    size = size,
    color = color,
    quantity = quantity,
    stockLimit = stockLimit,
    wholesalePrice = if (item.hasWholesale) item.wholesalePrice else 0.0,
    wholesaleMinQty = if (item.hasWholesale) item.wholesaleThreshold else 0,
)

private fun outOfStockMessage(item: Product, size: String, color: String, available: Int): String {
    val label = listOfNotNull(
        size.takeIf { it.isNotBlank() }?.let { "المقاس $it" },
        color.takeIf { it.isNotBlank() },
    ).joinToString(" - ")
    return when {
        available <= 0 && label.isNotBlank() -> "$label لم يعد متوفرًا من ${item.name}. اختاري خيارًا آخر."
        available <= 0 -> "نفدت كمية ${item.name} حاليًا."
        label.isNotBlank() -> "المتوفر من $label هو $available قطعة فقط."
        else -> "المتوفر في المخزون $available قطعة فقط."
    }
}

@Composable
private fun PurchaseBar(
    total: Double,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onAdd: (Offset) -> Unit,
    onBuyNow: () -> Unit,
) {
    var addAnchor by remember { mutableStateOf(Offset.Zero) }
    Column(modifier.background(MaterialTheme.colorScheme.surface)) {
        HorizontalDivider(color = MaterialTheme.colorScheme.outline)
        Row(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedButton(
                onClick = { onAdd(addAnchor) },
                enabled = enabled,
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier
                    .width(104.dp)
                    .height(46.dp)
                    .onGloballyPositioned { addAnchor = it.boundsInRoot().center },
            ) {
                Icon(Icons.Default.ShoppingBag, null, Modifier.size(17.dp))
                Spacer(Modifier.width(5.dp))
                Text("السلة")
            }
            Button(
                onClick = onBuyNow,
                enabled = enabled,
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier
                    .weight(1f)
                    .height(46.dp),
            ) {
                Icon(Icons.Default.Bolt, null, Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("اشتري الآن · ${formatMoney(total)}")
            }
        }
    }
}
