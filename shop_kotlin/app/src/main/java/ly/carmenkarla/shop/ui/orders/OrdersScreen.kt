package ly.carmenkarla.shop.ui.orders

import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.SupportAgent
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import coil.compose.AsyncImage
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.OrderStatusLabels
import ly.carmenkarla.shop.data.SavedOrder
import ly.carmenkarla.shop.data.TrackingItem
import ly.carmenkarla.shop.ui.ProductImage
import ly.carmenkarla.shop.ui.formatMoney
import ly.carmenkarla.shop.ui.openSupportChat
import ly.carmenkarla.shop.ui.theme.Brand
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun OrdersScreen() {
    val app = ShopApp.instance
    val scope = rememberCoroutineScope()
    val tracking = remember { mutableStateMapOf<String, TrackingItem>() }
    var loadingId by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }

    fun refresh(order: SavedOrder) {
        if (order.trackingToken.isBlank()) return
        loadingId = order.orderId
        error = ""
        scope.launch {
            runCatching { app.repository.tracking(order.orderId, order.trackingToken) }
                .onSuccess { tracking[order.orderId] = it }
                .onFailure { error = it.message ?: "تعذر تحديث حالة الطلب" }
            loadingId = ""
        }
    }

    LaunchedEffect(app.orders.size) {
        app.orders.forEach { order ->
            if (order.trackingToken.isNotBlank() && !tracking.containsKey(order.orderId)) {
                runCatching { app.repository.tracking(order.orderId, order.trackingToken) }
                    .onSuccess { tracking[order.orderId] = it }
            }
        }
    }

    if (app.orders.isEmpty()) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(Icons.Outlined.ReceiptLong, null, Modifier.size(44.dp), tint = Brand.Muted)
            Text("لا توجد طلبات بعد", style = MaterialTheme.typography.titleMedium)
            Text(
                "طلباتك ستظهر هنا مع حالتها لحظة بلحظة",
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
            )
        }
        return
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (error.isNotEmpty()) {
            item {
                Text(error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.labelSmall)
            }
        }
        items(app.orders.toList(), key = { it.orderId }) { order ->
            OrderRow(
                order = order,
                live = tracking[order.orderId],
                busy = loadingId == order.orderId,
                onRefresh = { refresh(order) },
                onReorder = {
                    val added = app.reorder(order)
                    error = if (added > 0) "تمت إضافة منتجات الطلب إلى السلة."
                    else "تعذر إعادة الطلب — المنتجات غير محفوظة"
                },
            )
        }
    }
}

@Composable
private fun OrderRow(
    order: SavedOrder,
    live: TrackingItem?,
    busy: Boolean,
    onRefresh: () -> Unit,
    onReorder: () -> Unit,
) {
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current
    var expanded by remember { mutableStateOf(false) }
    val status = live?.status ?: "pending"
    val shape = RoundedCornerShape(10.dp)
    val date = remember(order.createdAtMs) {
        if (order.createdAtMs <= 0) "" else
            SimpleDateFormat("dd/MM/yyyy", Locale("ar")).format(Date(order.createdAtMs))
    }

    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outline, shape)
            .clickable { expanded = !expanded }
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (order.items.isNotEmpty()) {
                Box(Modifier.width(if (order.items.size > 1) 56.dp else 36.dp)) {
                    order.items.take(3).reversed().forEachIndexed { stackIndex, line ->
                        val depth = minOf(order.items.size, 3) - 1 - stackIndex
                        ProductImage(
                            line.imageUrl,
                            Modifier
                                .padding(start = (depth * 10).dp)
                                .size(width = 36.dp, height = 44.dp)
                                .clip(RoundedCornerShape(5.dp))
                                .border(1.dp, MaterialTheme.colorScheme.surface, RoundedCornerShape(5.dp)),
                        )
                    }
                }
                Spacer(Modifier.width(9.dp))
            }
            Column(Modifier.weight(1f)) {
                Text(
                    "طلب #${order.orderId.takeLast(6)}",
                    style = MaterialTheme.typography.labelLarge,
                )
                Text(
                    "$date · ${order.itemCount} قطعة · ${formatMoney(order.total)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.Muted,
                )
                Spacer(Modifier.height(3.dp))
                StatusPill(status)
            }
            if (busy) {
                CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp)
            } else {
                Icon(
                    Icons.Outlined.Refresh,
                    "تحديث",
                    Modifier
                        .size(16.dp)
                        .clickable(onClick = onRefresh),
                    tint = Brand.Muted,
                )
            }
        }

        if (status in setOf("canceled", "returned", "returning")) {
            val reason = live?.statusReason.orEmpty().ifBlank { live?.externalDelivery?.providerStatus.orEmpty() }
            Text(
                reason.ifBlank { "ألغت شركة التوصيل الشحنة أو حُذفت من درب السبيل." },
                style = MaterialTheme.typography.labelSmall,
                color = Brand.Muted,
            )
            if (live?.statusReasonImageUrl.orEmpty().isNotBlank()) {
                AsyncImage(
                    model = live?.statusReasonImageUrl,
                    contentDescription = "صورة سبب الحالة",
                    contentScale = ContentScale.Inside,
                    modifier = Modifier.fillMaxWidth().heightIn(max = 220.dp).clip(RoundedCornerShape(6.dp)),
                )
            }
        } else if (status == "postponed") {
            Text(
                live?.statusReason.orEmpty().ifBlank { "تم تأجيل التوصيل، وسيتم تحديث الموعد عند توفره." },
                style = MaterialTheme.typography.labelSmall,
                color = Brand.Muted,
            )
            if (live?.statusReasonImageUrl.orEmpty().isNotBlank()) {
                AsyncImage(
                    model = live?.statusReasonImageUrl,
                    contentDescription = "صورة سبب التأجيل",
                    contentScale = ContentScale.Inside,
                    modifier = Modifier.fillMaxWidth().heightIn(max = 220.dp).clip(RoundedCornerShape(6.dp)),
                )
            }
        } else {
            Stepper(status)
        }

        if (live?.externalDelivery?.courierPhone.orEmpty().isNotBlank()) {
            Text("رقم مندوب التوصيل: ${live?.externalDelivery?.courierPhone}", style = MaterialTheme.typography.labelSmall, color = Brand.Rose)
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            val code = live?.externalDelivery?.let { it.referenceCode.ifBlank { it.trackingNumber } }.orEmpty()
            if (code.isNotBlank()) {
                Row(
                    Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .clickable { clipboard.setText(AnnotatedString(code)) }
                        .padding(horizontal = 7.dp, vertical = 3.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.ContentCopy, null, Modifier.size(11.dp), tint = Brand.Muted)
                    Spacer(Modifier.width(4.dp))
                    Text("شحنة $code", style = MaterialTheme.typography.labelSmall, color = Brand.Ink)
                }
            }
            Spacer(Modifier.weight(1f))
            Text(
                if (expanded) "إخفاء التفاصيل" else "عرض التفاصيل",
                style = MaterialTheme.typography.labelSmall,
                color = Brand.Rose,
            )
        }

        val activeToken = live?.trackingToken.orEmpty().ifBlank { order.trackingToken }
        val trackingLink = if (activeToken.isNotBlank()) {
            "${ly.carmenkarla.shop.data.STOREFRONT_URL}/track/?order=${java.net.URLEncoder.encode(order.orderId, "UTF-8")}&token=${java.net.URLEncoder.encode(activeToken, "UTF-8")}"
        } else {
            "${ly.carmenkarla.shop.data.STOREFRONT_URL}/track/?order=${java.net.URLEncoder.encode(order.orderId, "UTF-8")}"
        }

        OutlinedButton(
            onClick = {
                context.startActivity(
                    Intent.createChooser(
                        Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, "تابعي حالة طلبي من Carmen Karla:\n$trackingLink")
                        },
                        "متابعة الطلبية ومشاركة الرابط",
                    ),
                )
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(Icons.Outlined.ContentCopy, null, Modifier.size(15.dp))
            Spacer(Modifier.width(5.dp))
            Text("متابعة الطلبية ومشاركة الرابط")
        }

        val needsHelp = status in setOf("canceled", "returned", "returning", "postponed")
        val canReorder = status == "canceled" && order.items.any { it.productId.isNotBlank() }

        AnimatedVisibility(expanded) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                HorizontalDivider(color = MaterialTheme.colorScheme.outline)
                order.items.forEach { line ->
                    Row(Modifier.fillMaxWidth()) {
                        Text(
                            buildString {
                                append(line.name)
                                if (line.size.isNotBlank()) append(" · مقاس ${line.size}")
                                if (line.color.isNotBlank()) append(" · ${line.color}")
                                if (line.quantity > 1) append(" ×${line.quantity}")
                                if (line.size.isBlank()) append(" · المقاس غير محفوظ لهذا الطلب القديم")
                            },
                            Modifier.weight(1f),
                            style = MaterialTheme.typography.labelSmall,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            formatMoney(line.price * line.quantity),
                            style = MaterialTheme.typography.labelSmall,
                        )
                    }
                }
                if (order.shipping > 0) {
                    Row(Modifier.fillMaxWidth()) {
                        Text(
                            "التوصيل",
                            Modifier.weight(1f),
                            style = MaterialTheme.typography.labelSmall,
                            color = Brand.Muted,
                        )
                        Text(formatMoney(order.shipping), style = MaterialTheme.typography.labelSmall)
                    }
                }
                val place = listOf(order.city, order.address)
                    .filter { it.isNotBlank() }
                    .joinToString(" · ")
                if (place.isNotBlank()) {
                    Text(
                        "التوصيل إلى: $place",
                        style = MaterialTheme.typography.labelSmall,
                        color = Brand.Muted,
                    )
                }
                Text(
                    "الدفع عند الاستلام",
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.Muted,
                )
            }
        }

        if (needsHelp || canReorder) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (canReorder) {
                    OutlinedButton(
                        onClick = onReorder,
                        shape = RoundedCornerShape(7.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
                        modifier = Modifier.height(30.dp),
                    ) {
                        Icon(Icons.Outlined.Refresh, null, Modifier.size(13.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("إعادة الطلب", style = MaterialTheme.typography.labelSmall)
                    }
                }
                if (needsHelp) {
                    OutlinedButton(
                        onClick = {
                            openSupportChat(
                                context,
                                "مرحبًا، أحتاج مساعدة بخصوص الطلب ${order.orderId}",
                            )
                        },
                        shape = RoundedCornerShape(7.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 0.dp),
                        modifier = Modifier.height(30.dp),
                    ) {
                        Icon(Icons.Outlined.SupportAgent, null, Modifier.size(13.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("تواصلي مع الدعم", style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusPill(status: String) {
    val tint = when (status) {
        "delivered" -> Color(0xFF1E7F52)
        "shipped" -> Color(0xFF1D6FB8)
        "postponed" -> Color(0xFFB07A12)
        "canceled", "returned", "returning" -> MaterialTheme.colorScheme.error
        else -> Brand.Muted
    }
    Text(
        OrderStatusLabels.of(status),
        Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(tint.copy(alpha = 0.1f))
            .padding(horizontal = 9.dp, vertical = 3.dp),
        style = MaterialTheme.typography.labelSmall,
        color = tint,
        fontWeight = FontWeight.SemiBold,
    )
}

@Composable
private fun Stepper(status: String) {
    val current = OrderStatusLabels.steps.indexOf(status).let { if (it < 0) 0 else it }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        OrderStatusLabels.stepLabels.forEachIndexed { index, label ->
            val done = index <= current
            Column(
                Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(2.dp)
                            .background(
                                if (index <= current) Brand.Ink else MaterialTheme.colorScheme.outline,
                            ),
                    )
                    Box(
                        Modifier
                            .size(16.dp)
                            .clip(CircleShape)
                            .background(if (done) Brand.Ink else MaterialTheme.colorScheme.surfaceVariant),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (done) {
                            Icon(Icons.Default.Check, null, Modifier.size(10.dp), tint = Color.White)
                        }
                    }
                }
                Spacer(Modifier.height(4.dp))
                Text(
                    label,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (done) Brand.Ink else Brand.Muted,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                )
            }
        }
    }
}
