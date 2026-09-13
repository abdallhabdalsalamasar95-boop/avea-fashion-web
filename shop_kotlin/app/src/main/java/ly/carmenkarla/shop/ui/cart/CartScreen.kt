package ly.carmenkarla.shop.ui.cart

import android.content.Intent
import android.widget.Toast
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.ShoppingBag
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.CartLine
import ly.carmenkarla.shop.ui.ProductImage
import ly.carmenkarla.shop.ui.formatMoney
import ly.carmenkarla.shop.ui.theme.Brand

@Composable
fun CartScreen(onCheckout: () -> Unit, onContinueShopping: () -> Unit) {
    val app = ShopApp.instance
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var sharing by remember { mutableStateOf(false) }

    if (app.cart.isEmpty()) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(28.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(Icons.Outlined.ShoppingBag, null, Modifier.size(44.dp), tint = Brand.Muted)
            Text("سلتك فارغة", style = MaterialTheme.typography.titleMedium)
            Text(
                "أضيفي القطع التي أعجبتك وتابعي الطلب",
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(4.dp))
            Button(onClick = onContinueShopping, modifier = Modifier.height(44.dp)) {
                Text("ابدئي التسوق")
            }
        }
        return
    }

    Column(Modifier.fillMaxSize()) {
        LazyColumn(
            Modifier.weight(1f),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(app.cart.toList(), key = { it.lineId }) { line -> CartRow(line) }
        }

        Column(
            Modifier
                .background(MaterialTheme.colorScheme.surface)
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "المجموع",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Brand.Muted,
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    "(${app.cartCount} قطعة)",
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.Muted,
                )
                Spacer(Modifier.weight(1f))
                Text(
                    formatMoney(app.cartSubtotal),
                    style = MaterialTheme.typography.titleLarge,
                )
            }
            Text(
                "تُضاف تكلفة التوصيل حسب المدينة في الخطوة التالية",
                style = MaterialTheme.typography.labelSmall,
                color = Brand.Muted,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = onCheckout,
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                ) { Text("إتمام الطلب") }
                OutlinedButton(
                    onClick = {
                        sharing = true
                        scope.launch {
                            val ambassador = app.ambassador
                            val token = if (ambassador == null) "" else
                                app.repository.shareToken(app.account.idToken())
                            val link = app.repository.sharedCartLink(app.cart.toList(), token)
                            val text = if (ambassador == null) {
                                "شوفي اختياراتي من متجر Carmen Karla"
                            } else {
                                "اختيار خاص لكِ من شريكة Carmen Karla المعتمدة ${ambassador.ambassadorName}"
                            }
                            context.startActivity(
                                Intent.createChooser(
                                    Intent(Intent.ACTION_SEND).apply {
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_TEXT, "$text\n$link")
                                    },
                                    "مشاركة عبر",
                                ),
                            )
                            sharing = false
                        }
                    },
                    enabled = !sharing,
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .width(120.dp)
                        .height(48.dp),
                ) {
                    if (sharing) {
                        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                    } else {
                        Icon(Icons.Outlined.Share, null, Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("مشاركة")
                    }
                }
            }
        }
    }
}

@Composable
private fun CartRow(line: CartLine) {
    val app = ShopApp.instance
    val context = LocalContext.current
    val shape = RoundedCornerShape(10.dp)

    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outline, shape)
            .padding(10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        ProductImage(
            line.imageUrl,
            Modifier
                .size(width = 68.dp, height = 88.dp)
                .clip(RoundedCornerShape(7.dp)),
        )
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.Top) {
                Text(
                    line.name,
                    Modifier.weight(1f),
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Icon(
                    Icons.Outlined.DeleteOutline,
                    "حذف",
                    Modifier
                        .size(18.dp)
                        .clickable { app.removeLine(line.lineId) },
                    tint = Brand.Muted,
                )
            }

            Spacer(Modifier.height(5.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                if (line.size.isNotBlank()) OptionChip("المقاس ${line.size}")
                if (line.color.isNotBlank()) OptionChip(line.color)
                if (line.usesWholesale) OptionChip("سعر الجملة")
            }

            if (!line.usesWholesale && line.wholesaleMinQty > 1) {
                Spacer(Modifier.height(4.dp))
                Text(
                    "أضيفي ${line.wholesaleMinQty - line.quantity} قطعة للحصول على سعر الجملة",
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.Rose,
                )
            }

            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    formatMoney(line.lineTotal),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.weight(1f))
                Stepper(line.quantity) { next ->
                    if (line.stockLimit in 1..<next) {
                        Toast.makeText(
                            context,
                            "المتوفر من هذا الخيار ${line.stockLimit} قطعة فقط.",
                            Toast.LENGTH_SHORT,
                        ).show()
                    } else {
                        app.setQuantity(line.lineId, next)
                    }
                }
            }
        }
    }
}

@Composable
private fun OptionChip(text: String) {
    Text(
        text,
        Modifier
            .clip(RoundedCornerShape(5.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(horizontal = 7.dp, vertical = 3.dp),
        style = MaterialTheme.typography.labelSmall,
        color = Brand.Ink,
    )
}

@Composable
private fun Stepper(quantity: Int, onChange: (Int) -> Unit) {
    Row(
        Modifier
            .clip(RoundedCornerShape(7.dp))
            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(7.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StepButton("−") { onChange(quantity - 1) }
        Text(
            quantity.toString(),
            Modifier.width(28.dp),
            style = MaterialTheme.typography.titleSmall,
            textAlign = TextAlign.Center,
        )
        StepButton("+") { onChange(quantity + 1) }
    }
}

@Composable
private fun StepButton(label: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(30.dp)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = MaterialTheme.typography.titleMedium, color = Brand.Ink)
    }
}
