package ly.carmenkarla.shop.ui.ambassador

import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material.icons.filled.SupportAgent
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.AmbassadorOrder
import ly.carmenkarla.shop.data.AmbassadorProfile
import ly.carmenkarla.shop.data.OrderStatusLabels
import ly.carmenkarla.shop.data.WithdrawalSummary
import ly.carmenkarla.shop.ui.formatMoney
import ly.carmenkarla.shop.ui.openSupportChat
import ly.carmenkarla.shop.ui.theme.Brand
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private data class PortalStats(
    val sales: Double,
    val totalCommission: Double,
    val pending: Double,
    val earned: Double,
    val delivered: Int,
    val deliveryRate: Double,
)

private fun statsOf(orders: List<AmbassadorOrder>): PortalStats {
    val active = orders.filter { it.status != "canceled" }
    val delivered = active.count { it.status == "delivered" }
    val earned = active.filter { it.status == "delivered" }.sumOf { it.ambassadorSummary.commission }
    val total = active.sumOf { it.ambassadorSummary.commission }
    return PortalStats(
        sales = active.sumOf { it.grandTotal },
        totalCommission = total,
        pending = total - earned,
        earned = earned,
        delivered = delivered,
        deliveryRate = if (active.isEmpty()) 0.0 else delivered * 100.0 / active.size,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AmbassadorScreen(onBack: (() -> Unit)?, onStartOrder: () -> Unit) {
    val app = ShopApp.instance
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val profile = app.ambassador

    var tab by remember { mutableIntStateOf(0) }
    var orders by remember { mutableStateOf<List<AmbassadorOrder>?>(null) }
    var wallet by remember { mutableStateOf<WithdrawalSummary?>(null) }
    var message by remember { mutableStateOf("") }
    var editing by remember { mutableStateOf(false) }
    var reload by remember { mutableStateOf(0) }

    LaunchedEffect(profile?.uid, reload) {
        if (profile == null) return@LaunchedEffect
        val token = app.account.idToken()
        if (token.isBlank()) {
            message = "انتهت الجلسة، سجّلي الدخول مجددًا"
            return@LaunchedEffect
        }
        runCatching { app.repository.ambassadorOrders(token) }
            .onSuccess { orders = it }
            .onFailure { message = it.message.orEmpty() }
        runCatching { app.repository.ambassadorWithdrawals(token) }
            .onSuccess { wallet = it }
            .onFailure { message = it.message.orEmpty() }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(if (profile == null) "برنامج المندوبات" else "لوحة المندوبة") },
                navigationIcon = {
                    if (onBack != null) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, "رجوع")
                        }
                    }
                },
                actions = {
                    if (profile != null) {
                        IconButton(onClick = { reload++ }) { Icon(Icons.Default.Refresh, "تحديث") }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            if (profile == null || editing) {
                JoinForm(
                    existing = profile,
                    onDone = {
                        editing = false
                        reload++
                    },
                )
                return@Box
            }

            Column(Modifier.fillMaxSize()) {
                TabRow(
                    selectedTabIndex = tab,
                    containerColor = MaterialTheme.colorScheme.surface,
                ) {
                    Tab(tab == 0, { tab = 0 }, text = { Text("لوحتي") })
                    Tab(tab == 1, { tab = 1 }, text = { Text("طلبات عميلاتي") })
                }
                when (tab) {
                    0 -> DashboardTab(
                        profile = profile,
                        orders = orders,
                        wallet = wallet,
                        message = message,
                        onStartOrder = onStartOrder,
                        onEditProfile = { editing = true },
                        onShare = {
                            scope.launch {
                                message = ""
                                val token = app.account.idToken()
                                runCatching { app.repository.ambassadorShareLink(token) }
                                    .onSuccess { link ->
                                        val intent = Intent(Intent.ACTION_SEND).apply {
                                            type = "text/plain"
                                            putExtra(
                                                Intent.EXTRA_TEXT,
                                                "تسوّقي من كارمن كارلا عبر رابطي:\n$link",
                                            )
                                        }
                                        context.startActivity(Intent.createChooser(intent, "مشاركة الرابط"))
                                    }
                                    .onFailure { message = it.message.orEmpty() }
                            }
                        },
                        onWithdraw = {
                            scope.launch {
                                message = ""
                                val token = app.account.idToken()
                                runCatching { app.repository.requestWithdrawal(token) }
                                    .onSuccess {
                                        wallet = it
                                        message = "طلب السحب وصل إلى الإدارة وهو قيد المراجعة."
                                    }
                                    .onFailure { message = it.message.orEmpty() }
                            }
                        },
                    )
                    else -> OrdersTab(
                        orders = orders,
                        message = message,
                        onStartOrder = onStartOrder,
                        onCancel = { orderId ->
                            scope.launch {
                                message = ""
                                val token = app.account.idToken()
                                runCatching { app.repository.cancelAmbassadorOrder(token, orderId) }
                                    .onSuccess { reload++ }
                                    .onFailure { message = it.message.orEmpty() }
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun DashboardTab(
    profile: AmbassadorProfile,
    orders: List<AmbassadorOrder>?,
    wallet: WithdrawalSummary?,
    message: String,
    onStartOrder: () -> Unit,
    onEditProfile: () -> Unit,
    onShare: () -> Unit,
    onWithdraw: () -> Unit,
) {
    val stats = statsOf(orders.orEmpty())
    val context = LocalContext.current

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(Brush.horizontalGradient(listOf(Brand.RoseDark, Brand.Ink)))
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CheckCircle, null, Modifier.size(15.dp), tint = Brand.Gold)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "حساب مندوبة نشط",
                        style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.sp),
                        color = Brand.Gold,
                    )
                }
                Text(
                    "مرحبًا، ${profile.ambassadorName}",
                    style = MaterialTheme.typography.headlineSmall,
                    color = Color.White,
                )
                Text(
                    "تابعي مبيعاتك وعمولاتك وحالة كل طلب من مكان واحد.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.75f),
                )
            }
        }

        item { MotivationCard(stats, orders.orEmpty().size) }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(
                    Icons.Default.TrendingUp,
                    "إجمالي المبيعات",
                    formatMoney(stats.sales),
                    "${orders.orEmpty().size} طلب",
                    Modifier.weight(1f),
                )
                StatCard(
                    Icons.Default.Payments,
                    "إجمالي أرباحك",
                    formatMoney(stats.totalCommission),
                    "من كل الطلبات النشطة",
                    Modifier.weight(1f),
                    highlight = true,
                )
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard(
                    Icons.Default.Schedule,
                    "عمولة معلقة",
                    formatMoney(stats.pending),
                    "المعتمد: ${formatMoney(stats.earned)}",
                    Modifier.weight(1f),
                )
                StatCard(
                    Icons.Default.LocalShipping,
                    "نسبة نجاح التوصيل",
                    "${stats.deliveryRate.toInt()}%",
                    "${stats.delivered} طلب موصّل",
                    Modifier.weight(1f),
                )
            }
        }

        item { WithdrawalCard(wallet, onWithdraw) }

        if (message.isNotEmpty()) {
            item {
                Text(message, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
            }
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onStartOrder,
                    modifier = Modifier
                        .weight(1f)
                        .height(50.dp),
                ) {
                    Icon(Icons.Default.ShoppingBag, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("طلب جديد لعميلة")
                }
                OutlinedButton(
                    onClick = onShare,
                    modifier = Modifier
                        .weight(1f)
                        .height(50.dp),
                ) {
                    Icon(Icons.Default.Share, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("رابط المشاركة")
                }
            }
        }

        item {
            OutlinedButton(
                onClick = {
                    openSupportChat(
                        context,
                        "مرحبًا، أحتاج مساعدة بخصوص برنامج مندوبات Carmen Karla",
                    )
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(46.dp),
            ) {
                Icon(Icons.Default.SupportAgent, null, Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("دعم المندوبات")
            }
        }

        item {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(16.dp))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    "ملف المندوبة",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Person, null, Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(profile.ambassadorName, style = MaterialTheme.typography.titleSmall)
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Phone, null, Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(profile.ambassadorPhone, style = MaterialTheme.typography.bodyMedium)
                }
                Text(profile.ambassadorAddress, style = MaterialTheme.typography.bodySmall)
                TextButton(onClick = onEditProfile) { Text("تحديث البيانات") }
            }
        }
    }
}

/** Rotating coaching messages plus progress toward the next commission milestone. */
private val MOTIVATION_TIPS = listOf(
    "شاركي رابط منتج واحد يوميًا في الستوري — أغلب الطلبات تجي من الستوري.",
    "صوّري نفسك بالقطعة أو انشري صور المتجر مع سعرك، الثقة تزيد المبيعات.",
    "ردّي على استفسارات عميلاتك بسرعة، الرد السريع يضاعف فرصة إتمام الطلب.",
    "اقترحي قطعة مكمّلة مع كل طلب، الطلب الواحد ممكن يصير طلبين.",
    "احفظي مقاسات عميلاتك المتكررات وذكّريهن بالوصولات الجديدة.",
    "الطلبات الموصّلة هي اللي تتحوّل عمولة معتمدة — تابعي التوصيل مع عميلتك.",
)

private val MILESTONES = listOf(250.0, 500.0, 1000.0, 2500.0, 5000.0, 10000.0)

@Composable
private fun MotivationCard(stats: PortalStats, orderCount: Int) {
    val tip = remember(orderCount) {
        MOTIVATION_TIPS[((System.currentTimeMillis() / 86_400_000L).toInt() + orderCount).mod(MOTIVATION_TIPS.size)]
    }
    val target = MILESTONES.firstOrNull { it > stats.totalCommission } ?: MILESTONES.last()
    val progress = (stats.totalCommission / target).coerceIn(0.0, 1.0).toFloat()
    val headline = when {
        orderCount == 0 -> "بدايتك من هنا — أول طلب أهم خطوة!"
        stats.totalCommission <= 0.0 -> "طلباتك بدت تتحرك، واصلي!"
        progress >= 0.75 -> "ما بقالك شي! أنتِ قريبة من هدفك 🔥"
        progress >= 0.4 -> "أداء ممتاز، أنتِ في منتصف الطريق"
        else -> "كل مشاركة تقرّبك من هدفك"
    }

    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Brand.RoseSoft)
            .border(1.dp, Brand.Rose.copy(alpha = 0.25f), RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.AutoAwesome, null, Modifier.size(17.dp), tint = Brand.RoseDark)
            Spacer(Modifier.width(7.dp))
            Text(
                headline,
                style = MaterialTheme.typography.titleSmall,
                color = Brand.RoseDark,
                fontWeight = FontWeight.Bold,
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(7.dp)
                    .clip(RoundedCornerShape(4.dp)),
                color = Brand.RoseDark,
                trackColor = Color.White,
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    formatMoney(stats.totalCommission),
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.RoseDark,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    "الهدف القادم: ${formatMoney(target)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.Muted,
                )
            }
        }

        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White)
                .padding(10.dp),
        ) {
            Text("💡", style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.width(8.dp))
            Text(
                tip,
                style = MaterialTheme.typography.bodySmall,
                color = Brand.Ink,
            )
        }
    }
}

@Composable
private fun WithdrawalCard(wallet: WithdrawalSummary?, onWithdraw: () -> Unit) {    val minimum = wallet?.minimum ?: 100.0
    val available = wallet?.available ?: 0.0
    val pending = wallet?.pendingRequest
    val statusText = when (pending?.status) {
        "pending" -> "طلب السحب وصل إلى الإدارة وهو قيد المراجعة."
        "approved" -> "وافقت الإدارة على طلب السحب، وسيتم تحويل المبلغ قريبًا."
        "paid" -> "تم دفع مبلغ طلب السحب من الإدارة."
        "rejected" -> "لم تتم الموافقة على طلب السحب، وعاد المبلغ إلى رصيدك المتاح."
        else -> if (available >= minimum) "رصيدك جاهز للسحب الآن."
        else "يتاح السحب عند وصول الأرباح المعتمدة إلى ${formatMoney(minimum)}."
    }

    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(18.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.AutoAwesome, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.secondary)
            Spacer(Modifier.width(7.dp))
            Text("رصيد السحب", style = MaterialTheme.typography.labelMedium)
        }
        Text(
            formatMoney(available),
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.primary,
        )
        LinearProgressIndicator(
            progress = { (available / minimum).toFloat().coerceIn(0f, 1f) },
            modifier = Modifier
                .fillMaxWidth()
                .height(7.dp)
                .clip(RoundedCornerShape(30.dp)),
        )
        Text(statusText, style = MaterialTheme.typography.bodySmall)

        Button(
            onClick = onWithdraw,
            enabled = wallet?.canRequest == true && pending == null,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
        ) {
            Text(
                when {
                    pending != null -> "طلب سحب ${formatMoney(pending.amount)} قيد المراجعة"
                    available >= minimum -> "سحب ${formatMoney(available)}"
                    else -> "يتاح عند ${formatMoney(minimum)}"
                },
            )
        }

        val history = wallet?.requests.orEmpty().filter { it.id != pending?.id }
        if (history.isNotEmpty()) {
            history.take(5).forEach { request ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(formatMoney(request.amount), style = MaterialTheme.typography.labelMedium)
                    Text(
                        "${statusLabel(request.status)} · ${formatDate(request.createdAtMs)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun AmbassadorOrderCard(order: AmbassadorOrder, onCancel: (String) -> Unit) {
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    var expanded by remember { mutableStateOf(false) }
    var viewedReasonImage by remember { mutableStateOf<String?>(null) }
    val trackingLink = if (order.trackingToken.isNotBlank()) {
        "${ly.carmenkarla.shop.data.STOREFRONT_URL}/track/?order=" +
            java.net.URLEncoder.encode(order.orderId, "UTF-8") +
            "&token=" + java.net.URLEncoder.encode(order.trackingToken, "UTF-8")
    } else ""

    val firstLine = order.payload.items.firstOrNull()
    val otherItemsCount = maxOf(0, order.itemsCount - 1)
    val app = ShopApp.instance

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable { expanded = !expanded },
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        shape = RoundedCornerShape(12.dp),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (expanded) MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)
            else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.7f),
        ),
    ) {
        Column(
            Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            // Main compact header row: Thumbnail + Details + Status + Arrow
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Product Thumbnail
                Box(
                    Modifier
                        .size(width = 44.dp, height = 52.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.BottomEnd,
                ) {
                    val resolvedUrl = firstLine?.imageUrl?.takeIf { it.isNotBlank() }?.let { app.repository.absoluteUrl(it) }
                    if (resolvedUrl != null) {
                        AsyncImage(
                            model = resolvedUrl,
                            contentDescription = firstLine.name,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize(),
                        )
                    } else {
                        Icon(
                            Icons.Default.ShoppingBag,
                            null,
                            Modifier.size(20.dp).align(Alignment.Center),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                        )
                    }
                    if (otherItemsCount > 0) {
                        Box(
                            Modifier
                                .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(topStart = 4.dp))
                                .padding(horizontal = 3.dp, vertical = 1.dp),
                        ) {
                            Text(
                                "+$otherItemsCount",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }

                Spacer(Modifier.width(10.dp))

                // Middle Info Column
                Column(Modifier.weight(1f)) {
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            order.customerName.ifBlank { "#${order.orderId.takeLast(6)}" },
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false),
                        )
                        StatusPill(order.status)
                    }

                    Spacer(Modifier.height(2.dp))

                    Text(
                        listOfNotNull(
                            order.customerCity.takeIf { it.isNotBlank() },
                            formatDate(order.createdAtMs).takeIf { it.isNotBlank() },
                            "${order.itemsCount} قطعة",
                        ).joinToString(" · "),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )

                    Spacer(Modifier.height(3.dp))

                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            formatMoney(order.grandTotal),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.SemiBold,
                        )
                        val commission = order.ambassadorSummary.commission
                        if (commission > 0) {
                            Text(
                                if (order.status == "delivered") "عمولتك ${formatMoney(commission)}"
                                else "عمولة متوقعة ${formatMoney(commission)}",
                                style = MaterialTheme.typography.labelSmall,
                                color = if (order.status == "delivered") Color(0xFF2E7D5B) else Brand.RoseDark,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }

                Spacer(Modifier.width(4.dp))

                Icon(
                    if (expanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                    contentDescription = if (expanded) "إخفاء التفاصيل" else "عرض التفاصيل",
                    Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                )
            }

            // Expanded Details Section
            AnimatedVisibility(expanded) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    HorizontalDivider(
                        thickness = 0.8.dp,
                        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                    )

                    // Customer & Delivery Details Box
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
                            .padding(8.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        if (order.customerPhone.isNotBlank()) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    "الهاتف: ${order.customerPhone}",
                                    style = MaterialTheme.typography.bodySmall,
                                    modifier = Modifier.weight(1f),
                                )
                                Icon(
                                    Icons.Default.ContentCopy,
                                    "نسخ الهاتف",
                                    Modifier
                                        .size(15.dp)
                                        .clickable { clipboard.setText(AnnotatedString(order.customerPhone)) },
                                    tint = Brand.Muted,
                                )
                            }
                        }
                        if (order.customerAddress.isNotBlank()) {
                            Text(
                                "العنوان: ${order.customerAddress}",
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                        val code = order.externalDelivery.referenceCode.ifBlank { order.externalDelivery.trackingNumber }
                        if (code.isNotBlank()) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    "رقم الشحنة: $code",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Brand.Ink,
                                    modifier = Modifier.weight(1f),
                                )
                                Icon(
                                    Icons.Default.ContentCopy,
                                    "نسخ الشحنة",
                                    Modifier
                                        .size(15.dp)
                                        .clickable { clipboard.setText(AnnotatedString(code)) },
                                    tint = Brand.Muted,
                                )
                            }
                        }
                    }

                    // Product Line Thumbs List (when more than 1 product)
                    if (order.payload.items.size > 1) {
                        Text("القطع المطلوبة:", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(order.payload.items) { line ->
                                OrderLineThumb(line.imageUrl, line.size)
                            }
                        }
                    }

                    // Status notes & warnings
                    if (order.status == "returning") {
                        Text(
                            "الطلب قيد الإرجاع إلى المخزن. لا تُحتسب عمولته ولا تعتبر القطع متاحة للبيع قبل الفحص.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                    if (order.status == "returned") {
                        Text(
                            "تم استلام الشحنة المرتجعة في المخزن، وسيتم تحديد حالة القطع بعد الفحص.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (order.statusReason.isNotBlank()) {
                        val title = when (order.status) {
                            "postponed" -> "سبب التأجيل"
                            "canceled" -> "سبب الإلغاء"
                            "returning" -> "سبب الإرجاع"
                            "returned" -> "ملاحظة المرتجع"
                            else -> "ملاحظة الحالة"
                        }
                        Text("$title: ${order.statusReason}", style = MaterialTheme.typography.bodySmall)
                    }

                    // Delivery Reason Photos (if any)
                    val reasonImages = (order.statusReasonImageUrls + order.statusReasonImageUrl)
                        .filter { it.isNotBlank() }
                        .distinct()
                    if (reasonImages.isNotEmpty()) {
                        Text("صور من شركة التوصيل (اضغطي للتكبير)", style = MaterialTheme.typography.labelSmall, color = Brand.Rose)
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            items(reasonImages.take(6)) { imageUrl ->
                                AsyncImage(
                                    model = imageUrl,
                                    contentDescription = "صورة سبب الحالة",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier
                                        .size(width = 72.dp, height = 86.dp)
                                        .clip(RoundedCornerShape(6.dp))
                                        .clickable { viewedReasonImage = imageUrl },
                                )
                            }
                        }
                    }

                    // Compact Action Buttons Row
                    if (trackingLink.isNotBlank() || order.isCancelable) {
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            if (trackingLink.isNotBlank()) {
                                OutlinedButton(
                                    onClick = {
                                        context.startActivity(
                                            Intent.createChooser(
                                                Intent(Intent.ACTION_SEND).apply {
                                                    type = "text/plain"
                                                    putExtra(Intent.EXTRA_TEXT, "تابعي حالة طلبك من Carmen Karla:\n$trackingLink")
                                                },
                                                "مشاركة رابط تتبع الطلب",
                                            ),
                                        )
                                    },
                                    modifier = Modifier.height(34.dp).weight(1f),
                                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 0.dp),
                                    shape = RoundedCornerShape(8.dp),
                                ) {
                                    Icon(Icons.Default.Share, null, Modifier.size(13.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text("مشاركة التتبع", style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp))
                                }
                            }
                            if (order.isCancelable) {
                                OutlinedButton(
                                    onClick = { onCancel(order.orderId) },
                                    modifier = Modifier.height(34.dp).weight(1f),
                                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 0.dp),
                                    shape = RoundedCornerShape(8.dp),
                                    colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                                ) {
                                    Text("إلغاء الطلب", style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    viewedReasonImage?.let { imageUrl ->
        AlertDialog(
            onDismissRequest = { viewedReasonImage = null },
            confirmButton = { TextButton(onClick = { viewedReasonImage = null }) { Text("إغلاق") } },
            title = { Text("صورة من شركة التوصيل") },
            text = {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = "صورة سبب الحالة بالحجم الكامل",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxWidth().heightIn(max = 520.dp),
                )
            },
        )
    }
}

@Composable
private fun OrderLineThumb(imageUrl: String, size: String) {
    val app = ShopApp.instance
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        val resolved = imageUrl.takeIf { it.isNotBlank() }?.let { app.repository.absoluteUrl(it) }
        if (resolved != null) {
            AsyncImage(
                model = resolved,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(width = 44.dp, height = 56.dp)
                    .clip(RoundedCornerShape(8.dp)),
            )
        }
        if (size.isNotBlank()) {
            Text(size, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun OrdersTab(
    orders: List<AmbassadorOrder>?,
    message: String,
    onStartOrder: () -> Unit,
    onCancel: (String) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var statusFilter by remember { mutableStateOf("all") }
    var timeframe by remember { mutableStateOf("all") }
    var sortOrder by remember { mutableStateOf("newest") }
    if (orders == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(Modifier.size(30.dp))
        }
        return
    }
    if (orders.isEmpty()) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(32.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                Icons.Default.ShoppingBag,
                null,
                Modifier.size(48.dp),
                tint = MaterialTheme.colorScheme.secondary,
            )
            Text("ابدئي أول عملية بيع", style = MaterialTheme.typography.titleMedium)
            Text(
                "اختاري المنتجات وأدخلي بيانات عميلتك عند إتمام الطلب.",
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
            )
            Button(onClick = onStartOrder) { Text("تصفّحي المنتجات") }
        }
        return
    }

    val now = System.currentTimeMillis()
    val visibleOrders = orders
        .filter { order ->
            when (statusFilter) {
                "active" -> order.status in setOf("pending", "processing", "shipped", "returning")
                "completed" -> order.status in setOf("delivered", "returned")
                "postponed", "canceled", "returning" -> order.status == statusFilter
                else -> true
            }
        }
        .filter { order ->
            val term = query.trim()
            term.isBlank() || order.orderId.contains(term, true) ||
                order.customerName.contains(term, true) || order.customerPhone.contains(term) ||
                order.customerCity.contains(term, true) || order.customerAddress.contains(term, true) ||
                order.externalDelivery.referenceCode.contains(term, true) ||
                order.externalDelivery.trackingNumber.contains(term, true) ||
                order.payload.items.any { it.name.contains(term, true) || it.productCode.contains(term, true) }
        }
        .filter { order ->
            when (timeframe) {
                "today" -> order.createdAtMs >= now - 24L * 60 * 60 * 1000
                "week" -> order.createdAtMs >= now - 7L * 24 * 60 * 60 * 1000
                "month" -> order.createdAtMs >= now - 30L * 24 * 60 * 60 * 1000
                "three_months" -> order.createdAtMs >= now - 90L * 24 * 60 * 60 * 1000
                else -> true
            }
        }
        .sortedWith(
            when (sortOrder) {
                "oldest" -> compareBy { it.createdAtMs }
                "highest_price" -> compareByDescending<AmbassadorOrder> { it.grandTotal }
                else -> compareByDescending { it.createdAtMs }
            },
        )

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (message.isNotEmpty()) {
            item {
                Text(message, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
        }
        item {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                label = { Text("بحث برقم الطلب أو العميلة أو القطعة") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        item {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("all" to "الكل", "active" to "النشطة", "completed" to "المكتملة", "postponed" to "المؤجلة", "returning" to "قيد الإرجاع", "canceled" to "الملغاة").forEach { (id, label) ->
                    FilterChip(selected = statusFilter == id, onClick = { statusFilter = id }, label = { Text(label) })
                }
            }
        }
        item {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("all" to "كل الفترات", "today" to "اليوم", "week" to "7 أيام", "month" to "30 يوم", "three_months" to "3 أشهر").forEach { (id, label) ->
                    FilterChip(selected = timeframe == id, onClick = { timeframe = id }, label = { Text(label) })
                }
            }
        }
        item {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("newest" to "الأحدث", "oldest" to "الأقدم", "highest_price" to "الأعلى قيمة").forEach { (id, label) ->
                    FilterChip(selected = sortOrder == id, onClick = { sortOrder = id }, label = { Text(label) })
                }
            }
        }
        item {
            Text("${visibleOrders.size} من ${orders.size} طلب", style = MaterialTheme.typography.labelMedium)
        }
        if (query.isNotBlank() || statusFilter != "all" || timeframe != "all" || sortOrder != "newest") {
            item {
                TextButton(onClick = {
                    query = ""
                    statusFilter = "all"
                    timeframe = "all"
                    sortOrder = "newest"
                }) { Text("إعادة ضبط الفلاتر") }
            }
        }
        if (visibleOrders.isEmpty()) {
            item { Text("لا توجد طلبات تطابق البحث أو الفلاتر.", style = MaterialTheme.typography.bodyMedium) }
        }
        items(visibleOrders, key = { it.orderId }) { order ->
            AmbassadorOrderCard(order, onCancel)
        }
    }
}

@Composable
private fun JoinForm(existing: AmbassadorProfile?, onDone: () -> Unit) {
    val app = ShopApp.instance
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf(existing?.ambassadorName ?: app.account.displayName) }
    var phone by remember { mutableStateOf(existing?.ambassadorPhone.orEmpty()) }
    var address by remember { mutableStateOf(existing?.ambassadorAddress.orEmpty()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (existing == null) {
            item {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(20.dp))
                        .background(Brush.horizontalGradient(listOf(Brand.RoseDark, Brand.Ink)))
                        .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        "CARMEN KARLA PARTNERS",
                        style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 2.sp),
                        color = Brand.Gold,
                    )
                    Text(
                        "كوني مندوبة مبيعات",
                        style = MaterialTheme.typography.headlineSmall,
                        color = Color.White,
                    )
                    Text(
                        "بدون رسوم اشتراك، بدون بضاعة عندك، ووقت مرن. اطلبي للزبونة ونحن نشحن ونوصّل ونحاسبك.",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White.copy(alpha = 0.75f),
                    )
                }
            }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Step("1", "سجّلي بياناتك", "3 بيانات فقط، وبعدها تفتح لوحتك مباشرة.")
                    Step("2", "اطلبي للزبونة", "اختاري المنتجات وأدخلي عنوان عميلتك عند إتمام الطلب.")
                    Step("3", "استلمي أرباحك", "العمولة تُعتمد بعد التوصيل، واسحبيها عند 100 د.ل.")
                }
            }
        }

        item {
            Text(
                if (existing == null) "انضمام سريع" else "تعديل البيانات",
                style = MaterialTheme.typography.titleMedium,
            )
        }

        if (app.account.user == null) {
            item {
                Text(
                    "سجّلي الدخول من تبويب «حسابي» أولًا، ثم عودي إلى هنا.",
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            return@LazyColumn
        }

        item {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("الاسم الكامل") },
                placeholder = { Text("مثال: مريم محمد") },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        item {
            OutlinedTextField(
                value = phone,
                onValueChange = { phone = it },
                label = { Text("رقم الهاتف") },
                placeholder = { Text("09xxxxxxxx") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        item {
            OutlinedTextField(
                value = address,
                onValueChange = { address = it },
                label = { Text("المدينة والمنطقة") },
                placeholder = { Text("طرابلس - حي الأندلس") },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        if (error.isNotEmpty()) {
            item {
                Text(error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
        }

        item {
            Button(
                onClick = {
                    busy = true
                    error = ""
                    scope.launch {
                        val token = app.account.idToken()
                        runCatching { app.repository.saveAmbassadorProfile(token, name, phone, address) }
                            .onSuccess {
                                app.ambassador = it
                                onDone()
                            }
                            .onFailure { error = it.message ?: "تعذر حفظ البيانات" }
                        busy = false
                    }
                },
                enabled = !busy && name.isNotBlank() && phone.isNotBlank() && address.isNotBlank(),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
            ) {
                if (busy) CircularProgressIndicator(Modifier.size(20.dp), color = Color.White)
                else Text(if (existing == null) "تفعيل حساب المندوبة" else "حفظ التعديلات")
            }
        }
    }
}

@Composable
private fun Step(number: String, title: String, body: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = RoundedCornerShape(10.dp)) {
            Box(Modifier.size(32.dp), contentAlignment = Alignment.Center) {
                Text(
                    number,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                    style = MaterialTheme.typography.labelLarge,
                )
            }
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(body, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun StatCard(
    icon: ImageVector,
    label: String,
    value: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    highlight: Boolean = false,
) {
    val container = if (highlight) Brand.Ink else MaterialTheme.colorScheme.surface
    val onContainer = if (highlight) Color.White else MaterialTheme.colorScheme.onSurface
    Column(
        modifier
            .clip(RoundedCornerShape(16.dp))
            .background(container)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(16.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                icon,
                null,
                Modifier.size(15.dp),
                tint = if (highlight) Brand.Gold else MaterialTheme.colorScheme.secondary,
            )
            Spacer(Modifier.width(5.dp))
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                color = if (highlight) Color.White.copy(alpha = 0.8f) else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(value, style = MaterialTheme.typography.titleLarge, color = onContainer)
        Text(
            subtitle,
            style = MaterialTheme.typography.labelSmall,
            color = if (highlight) Color.White.copy(alpha = 0.6f) else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun StatusPill(status: String) {
    val color = when (status) {
        "delivered" -> Color(0xFF2E7D5B)
        "canceled", "returned" -> MaterialTheme.colorScheme.error
        "shipped" -> MaterialTheme.colorScheme.secondary
        else -> MaterialTheme.colorScheme.primary
    }
    Surface(color = color.copy(alpha = 0.12f), shape = RoundedCornerShape(30.dp)) {
        Text(
            OrderStatusLabels.of(status),
            Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = color,
        )
    }
}

private fun statusLabel(status: String) = when (status) {
    "pending" -> "قيد المراجعة"
    "approved" -> "تم قبول الطلب"
    "paid" -> "تم الدفع"
    "rejected" -> "تم رفض الطلب"
    else -> status
}

private fun formatDate(ms: Long): String =
    if (ms <= 0) "" else SimpleDateFormat("dd/MM/yyyy", Locale("ar")).format(Date(ms))
