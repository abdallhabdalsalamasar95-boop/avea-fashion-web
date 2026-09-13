package ly.carmenkarla.shop.ui.wholesale

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.Product
import ly.carmenkarla.shop.ui.ErrorBox
import ly.carmenkarla.shop.ui.CatalogSkeleton
import ly.carmenkarla.shop.ui.ProductCard
import ly.carmenkarla.shop.ui.openSupportChat
import ly.carmenkarla.shop.ui.theme.Brand

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WholesaleScreen(onBack: () -> Unit, onOpenProduct: (String) -> Unit) {
    val app = ShopApp.instance
    val settings = app.wholesale
    var items by remember { mutableStateOf<List<Product>?>(null) }
    var error by remember { mutableStateOf("") }
    var reload by remember { mutableIntStateOf(0) }

    LaunchedEffect(reload) {
        error = ""
        items = null
        runCatching { app.repository.products() }
            .onSuccess { catalog -> items = catalog.filter { it.hasWholesale } }
            .onFailure { error = it.message ?: "تعذر تحميل قسم الجملة" }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(settings.title.ifBlank { "قسم الجملة" }) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "رجوع") }
                },
            )
        },
    ) { padding ->
        val list = items
        when {
            error.isNotEmpty() -> Box(Modifier.padding(padding)) { ErrorBox(error, { reload++ }) }
            list == null -> Box(Modifier.padding(padding)) { CatalogSkeleton() }
            else -> LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(12.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                item(span = { GridItemSpan(2) }) { WholesaleBanner() }

                if (list.isEmpty()) {
                    item(span = { GridItemSpan(2) }) {
                        Text(
                            "لا توجد قطع بسعر جملة حاليًا. تابعينا قريبًا.",
                            Modifier
                                .fillMaxWidth()
                                .padding(vertical = 40.dp),
                            style = MaterialTheme.typography.bodyMedium,
                            color = Brand.Muted,
                            textAlign = TextAlign.Center,
                        )
                    }
                } else {
                    items(list, key = { it.id }) { product ->
                        ProductCard(product) { onOpenProduct(product.id) }
                    }
                }
            }
        }
    }
}

@Composable
private fun WholesaleBanner() {
    val app = ShopApp.instance
    val settings = app.wholesale
    val context = LocalContext.current

    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Brand.Ink)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.Inventory2, null, Modifier.size(18.dp), tint = Brand.Gold)
            Spacer(Modifier.width(8.dp))
            Text(
                settings.title.ifBlank { "قسم الجملة" },
                style = MaterialTheme.typography.titleMedium,
                color = Color.White,
                fontWeight = FontWeight.Bold,
            )
        }
        if (settings.subtitle.isNotBlank()) {
            Text(
                settings.subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.72f),
            )
        }
        if (settings.note.isNotBlank()) {
            Text(
                settings.note,
                style = MaterialTheme.typography.labelSmall,
                color = Brand.Gold,
            )
        }
        Text(
            "السعر ينزل تلقائيًا في السلة عند الوصول للحد الأدنى لكل قطعة.",
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.6f),
        )
        Row(
            Modifier
                .clip(RoundedCornerShape(9.dp))
                .background(Brand.Gold)
                .clickable {
                    openSupportChat(context, "مرحبًا، أريد الاستفسار عن أسعار الجملة")
                }
                .padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "تواصلي معنا للجملة",
                style = MaterialTheme.typography.labelLarge,
                color = Brand.Ink,
            )
        }
    }
}
