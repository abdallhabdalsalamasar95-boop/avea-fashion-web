package ly.carmenkarla.shop.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.ShoppingBag
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import ly.carmenkarla.shop.CartAddResult
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.CartLine
import ly.carmenkarla.shop.data.Product
import ly.carmenkarla.shop.ui.theme.Brand

@Composable
fun ProductCard(product: Product, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val app = ShopApp.instance
    val context = LocalContext.current
    val shape = RoundedCornerShape(10.dp)

    Column(
        modifier
            .clip(shape)
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outline, shape)
            .clickable(onClick = onClick)
            .padding(7.dp),
    ) {
        Box {
            ProductImage(
                product.gallery.firstOrNull().orEmpty(),
                Modifier
                    .fillMaxWidth()
                    .aspectRatio(0.85f)
                    .clip(RoundedCornerShape(6.dp)),
            )
            if (product.soldPieces >= 5) {
                Text(
                    "تم بيع +${product.soldPieces}",
                    Modifier
                        .align(Alignment.TopEnd)
                        .background(Brand.Ink, RoundedCornerShape(bottomStart = 8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    color = androidx.compose.ui.graphics.Color.White,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            if (product.soldOut) {
                Text(
                    "نفدت الكمية",
                    Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .background(Brand.Ink.copy(alpha = 0.82f))
                        .padding(vertical = 5.dp),
                    color = androidx.compose.ui.graphics.Color.White,
                    style = MaterialTheme.typography.labelSmall,
                    textAlign = TextAlign.Center,
                )
            }
        }

        Spacer(Modifier.height(8.dp))
        Text(
            product.name,
            style = MaterialTheme.typography.titleSmall,
            maxLines = 2,
            minLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        if (product.description.isNotBlank()) {
            Text(
                product.description,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                formatMoney(product.price),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )
            if (product.oldPrice > product.price) {
                Spacer(Modifier.width(5.dp))
                Text(
                    formatMoney(product.oldPrice),
                    style = MaterialTheme.typography.labelSmall,
                    textDecoration = TextDecoration.LineThrough,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.weight(1f))
            if (product.discountPercent > 0) {
                Text(
                    "%${product.discountPercent}-",
                    Modifier
                        .background(Brand.RoseSoft, RoundedCornerShape(5.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.Rose,
                    fontWeight = FontWeight.Bold,
                )
            }
        }

        if (app.activeAmbassador != null) {
            Spacer(Modifier.height(5.dp))
            CommissionPill(app.commission.amountFor(product))
        }

        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                Modifier
                    .weight(1f)
                    .height(36.dp)
                    .clip(RoundedCornerShape(7.dp))
                    .background(if (product.soldOut) Brand.Muted else Brand.Ink)
                    .clickable(
                        enabled = !product.soldOut,
                        onClick = {
                            val result = quickAdd(product, onClick)
                            if (result is CartAddResult.OutOfStock) {
                                Toast.makeText(
                                    context,
                                    "نفدت كمية ${product.name} — لم يعد متوفرًا.",
                                    Toast.LENGTH_SHORT,
                                ).show()
                            } else if (result is CartAddResult.Capped) {
                                Toast.makeText(
                                    context,
                                    "المتوفر ${result.available} قطعة فقط.",
                                    Toast.LENGTH_SHORT,
                                ).show()
                            }
                        },
                    ),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Outlined.ShoppingBag,
                    null,
                    Modifier.size(15.dp),
                    tint = androidx.compose.ui.graphics.Color.White,
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    "أضف للسلة",
                    style = MaterialTheme.typography.labelMedium,
                    color = androidx.compose.ui.graphics.Color.White,
                )
            }
            Box(
                Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(7.dp))
                    .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(7.dp))
                    .clickable { app.toggleFavorite(product.id) },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (app.isFavorite(product.id)) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    "المفضلة",
                    Modifier.size(17.dp),
                    tint = if (app.isFavorite(product.id)) Brand.Rose else Brand.Ink,
                )
            }
        }
    }
}

/** Only one-variant products can skip the detail page; anything else needs a size or colour. */
private fun quickAdd(product: Product, openDetails: () -> Unit): CartAddResult {
    val app = ShopApp.instance
    val size = product.availableSizes.singleOrNull() ?: ""
    val color = product.colors.singleOrNull() ?: ""
    val needsChoice = (product.availableSizes.size > 1) || (product.colors.size > 1) ||
        (product.availableSizes.isEmpty() && product.sizes.isNotEmpty())
    if (needsChoice) {
        openDetails()
        return CartAddResult.Added
    }
    return app.addToCart(
        CartLine(
            lineId = "${product.id}_${size}_$color",
            productId = product.id,
            productCode = product.productCode,
            name = product.name,
            price = product.price,
            imageUrl = product.gallery.firstOrNull().orEmpty(),
            size = size,
            color = color,
            quantity = 1,
            stockLimit = product.stockFor(size),
        ),
    )
}

@Composable
fun CommissionPill(amount: Double, modifier: Modifier = Modifier) {
    Row(
        modifier
            .clip(RoundedCornerShape(5.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(horizontal = 7.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("عمولتك", style = MaterialTheme.typography.labelSmall, color = Brand.Muted)
        Spacer(Modifier.width(5.dp))
        Text(
            formatMoney(amount),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = Brand.Gold,
        )
    }
}
