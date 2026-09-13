package ly.carmenkarla.shop.ui.account

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.LocalShipping
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material.icons.outlined.SupportAgent
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.data.AccountOrder
import ly.carmenkarla.shop.ui.openSupportChat
import ly.carmenkarla.shop.ui.theme.Brand

internal const val STOREFRONT = ly.carmenkarla.shop.data.STOREFRONT_URL

@Composable
fun AccountScreen(onOpenAmbassador: () -> Unit, onOpenSettings: () -> Unit) {
    val app = ShopApp.instance
    val context = LocalContext.current
    var signedIn by remember { mutableStateOf(app.account.user != null) }
    var orders by remember { mutableStateOf<List<AccountOrder>?>(null) }

    LaunchedEffect(app.accountRevision) {
        signedIn = app.account.user != null
    }

    LaunchedEffect(signedIn) {
        if (!signedIn) {
            orders = null
            app.ambassador = null
            return@LaunchedEffect
        }
        val token = app.account.idToken()
        if (token.isBlank()) return@LaunchedEffect
        app.refreshAmbassador()
        runCatching { app.repository.accountOrders(token) }.onSuccess { orders = it }
    }

    if (!signedIn) {
        SignInPane { signedIn = true }
        return
    }

    val ambassador = app.ambassador
    val remoteCount = orders?.size ?: 0
    val totalOrders = maxOf(remoteCount, app.orders.size)

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Brand.Ink),
            ) {
                Row(
                    Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(Brand.Gold),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            app.customer.value.name.take(1).ifBlank {
                                app.account.displayName.take(1).uppercase().ifBlank { "K" }
                            },
                            style = MaterialTheme.typography.titleLarge,
                            color = Brand.Ink,
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            app.customer.value.name.ifBlank { "مرحبًا بكِ" },
                            style = MaterialTheme.typography.titleMedium,
                            color = Color.White,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            app.account.displayName,
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.6f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        val extra = listOfNotNull(
                            app.customer.value.phone.takeIf { it.isNotBlank() },
                            app.customer.value.city.takeIf { it.isNotBlank() },
                        ).joinToString(" · ")
                        if (extra.isNotBlank()) {
                            Text(
                                extra,
                                style = MaterialTheme.typography.labelSmall,
                                color = Color.White.copy(alpha = 0.6f),
                            )
                        }
                    }
                    if (ambassador != null) {
                        Text(
                            "مندوبة معتمدة",
                            Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .background(Brand.Gold)
                                .padding(horizontal = 9.dp, vertical = 3.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = Brand.Ink,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }

                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(Color.White.copy(alpha = 0.12f)),
                )

                Row(Modifier.padding(vertical = 12.dp)) {
                    HeaderStat(totalOrders.toString(), "طلباتي", Modifier.weight(1f))
                    HeaderStat(app.favorites.size.toString(), "المفضلة", Modifier.weight(1f))
                    HeaderStat(app.cartCount.toString(), "في السلة", Modifier.weight(1f))
                }

                if (ambassador != null) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(Color.White.copy(alpha = 0.12f)),
                    )
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                if (app.ambassadorMode) "وضع المندوبة" else "وضع الزبونة",
                                style = MaterialTheme.typography.labelLarge,
                                color = Color.White,
                            )
                            Text(
                                if (app.ambassadorMode) "طلباتك تُحتسب لكِ عمولة"
                                else "تتسوقين لنفسك — بدون عمولة",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color.White.copy(alpha = 0.6f),
                            )
                        }
                        Switch(
                            checked = app.ambassadorMode,
                            onCheckedChange = { app.ambassadorMode = it },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = Brand.Ink,
                                checkedTrackColor = Brand.Gold,
                            ),
                        )
                    }
                }
            }
        }

        if (orders != null && orders!!.isNotEmpty()) {
            val active = orders!!.firstOrNull { it.status !in setOf("delivered", "canceled", "returned") }
            if (active != null) {
                item {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(MaterialTheme.colorScheme.surface)
                            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Outlined.LocalShipping, null, Modifier.size(20.dp), tint = Brand.Rose)
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text("طلب #${active.orderId.takeLast(6)}", style = MaterialTheme.typography.titleSmall)
                            Text(
                                ly.carmenkarla.shop.data.OrderStatusLabels.of(active.status),
                                style = MaterialTheme.typography.labelSmall,
                                color = Brand.Rose,
                            )
                        }
                    }
                }
            }
        }

        item { SectionLabel("حسابي") }
        item {
            MenuGroup(
                listOf(
                    MenuRow(
                        Icons.Outlined.Storefront,
                        "لوحة المندوبة",
                        if (ambassador != null) "تابعي أرباحك وطلبات عميلاتك"
                        else "انضمي واربحي عمولة على كل طلب",
                        onOpenAmbassador,
                    ),
                    MenuRow(
                        Icons.Outlined.SupportAgent,
                        "تواصلي مع الدعم",
                        "واتساب · رد سريع",
                    ) {
                        openSupportChat(context, "مرحبًا، أحتاج مساعدة من متجر Carmen Karla")
                    },
                    MenuRow(
                        Icons.Outlined.Settings,
                        "الإعدادات",
                        "بياناتي · العنوان · السياسات",
                        onOpenSettings,
                    ),
                ),
            )
        }

        item {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                    .clickable {
                        app.account.signOut()
                        signedIn = false
                    }
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                Icon(
                    Icons.AutoMirrored.Outlined.Logout,
                    null,
                    Modifier.size(17.dp),
                    tint = MaterialTheme.colorScheme.error,
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "تسجيل الخروج",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}

@Composable
internal fun DetailsDialog(onDismiss: () -> Unit) {
    val app = ShopApp.instance
    val saved = app.customer.value
    var name by remember { mutableStateOf(saved.name) }
    var phone by remember { mutableStateOf(saved.phone) }
    var city by remember { mutableStateOf(saved.city) }
    var area by remember { mutableStateOf(saved.area) }
    var address by remember { mutableStateOf(saved.address) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("بياناتي") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    "تُعبّأ تلقائيًا عند إتمام الطلب",
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.Muted,
                )
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("الاسم الكامل") },
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = phone,
                    onValueChange = { phone = it },
                    label = { Text("رقم الهاتف") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = city,
                        onValueChange = { city = it },
                        label = { Text("المدينة") },
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.weight(1f),
                    )
                    OutlinedTextField(
                        value = area,
                        onValueChange = { area = it },
                        label = { Text("المنطقة") },
                        singleLine = true,
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.weight(1f),
                    )
                }
                OutlinedTextField(
                    value = address,
                    onValueChange = { address = it },
                    label = { Text("العنوان بالتفصيل") },
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                app.rememberCustomer(
                    app.customer.value.copy(
                        name = name.trim(),
                        phone = phone.trim(),
                        city = city.trim(),
                        area = area.trim(),
                        address = address.trim(),
                    ),
                )
                onDismiss()
            }) { Text("حفظ") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("إلغاء") } },
    )
}

internal fun openLink(context: android.content.Context, url: String) {
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
}

private data class MenuRow(
    val icon: ImageVector,
    val title: String,
    val subtitle: String,
    val onClick: (() -> Unit)?,
)
@Composable
private fun MenuGroup(rows: List<MenuRow>) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp)),
    ) {
        rows.forEachIndexed { index, row ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .then(if (row.onClick != null) Modifier.clickable(onClick = row.onClick) else Modifier)
                    .padding(horizontal = 12.dp, vertical = 11.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(row.icon, null, Modifier.size(19.dp), tint = Brand.Ink)
                Spacer(Modifier.width(11.dp))
                Column(Modifier.weight(1f)) {
                    Text(row.title, style = MaterialTheme.typography.titleSmall)
                    Text(
                        row.subtitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = Brand.Muted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                if (row.onClick != null) {
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                        null,
                        Modifier.size(18.dp),
                        tint = Brand.Muted,
                    )
                }
            }
            if (index != rows.lastIndex) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .padding(start = 42.dp)
                        .height(1.dp)
                        .background(MaterialTheme.colorScheme.outline),
                )
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        Modifier.padding(start = 2.dp),
        style = MaterialTheme.typography.labelSmall,
        color = Brand.Muted,
    )
}

@Composable
private fun HeaderStat(value: String, label: String, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleMedium, color = Color.White)
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.6f),
        )
    }
}

/** Four-colour Google mark drawn inline so no extra drawable asset is needed. */
@Composable
private fun GoogleGlyph() {
    Canvas(Modifier.size(17.dp)) {
        val stroke = size.minDimension * 0.26f
        val inset = stroke / 2
        val arc = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke)
        val offset = androidx.compose.ui.geometry.Offset(inset, inset)
        listOf(
            Color(0xFF4285F4) to (-45f to 90f),
            Color(0xFF34A853) to (45f to 90f),
            Color(0xFFFBBC05) to (135f to 90f),
            Color(0xFFEA4335) to (225f to 90f),
        ).forEach { (color, sweep) ->
            drawArc(
                color = color,
                startAngle = sweep.first,
                sweepAngle = sweep.second,
                useCenter = false,
                topLeft = offset,
                size = arc,
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = stroke),
            )
        }
        drawRect(
            color = Color(0xFF4285F4),
            topLeft = androidx.compose.ui.geometry.Offset(size.width / 2, size.height / 2 - stroke / 2),
            size = androidx.compose.ui.geometry.Size(size.width / 2, stroke),
        )
    }
}

@Composable
private fun SignInPane(onSignedIn: () -> Unit) {
    val app = ShopApp.instance
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var registerMode by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(
                Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(
                    Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(Brand.Ink),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.Person, null, Modifier.size(26.dp), tint = Color.White)
                }
                Spacer(Modifier.height(10.dp))
                Text(
                    if (registerMode) "إنشاء حساب جديد" else "تسجيل الدخول",
                    style = MaterialTheme.typography.titleLarge,
                )
                Text(
                    "احفظي طلباتك ومفضلاتك، وتابعي حالة التوصيل",
                    style = MaterialTheme.typography.bodySmall,
                    textAlign = TextAlign.Center,
                )
            }
        }
        item {
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                    .clickable(enabled = !busy) {
                        context.startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("$STOREFRONT/app-auth/"),
                            ),
                        )
                    },
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                GoogleGlyph()
                Spacer(Modifier.width(9.dp))
                Text("المتابعة بحساب Google", style = MaterialTheme.typography.labelLarge)
            }
        }
        item {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    Modifier
                        .weight(1f)
                        .height(1.dp)
                        .background(MaterialTheme.colorScheme.outline),
                )
                Text(
                    "  أو بالبريد  ",
                    style = MaterialTheme.typography.labelSmall,
                    color = Brand.Muted,
                )
                Box(
                    Modifier
                        .weight(1f)
                        .height(1.dp)
                        .background(MaterialTheme.colorScheme.outline),
                )
            }
        }
        item {
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("البريد الإلكتروني") },
                singleLine = true,
                shape = RoundedCornerShape(10.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        item {
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("كلمة المرور") },
                singleLine = true,
                shape = RoundedCornerShape(10.dp),
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        if (message.isNotEmpty()) {
            item {
                Text(message, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.labelSmall)
            }
        }
        item {
            Button(
                onClick = {
                    busy = true
                    message = ""
                    scope.launch {
                        runCatching {
                            if (registerMode) app.account.register(email, password)
                            else app.account.signIn(email, password)
                        }
                            .onSuccess {
                                password = ""
                                onSignedIn()
                            }
                            .onFailure { message = it.message ?: "تعذر إتمام العملية" }
                        busy = false
                    }
                },
                enabled = !busy && email.isNotBlank() && password.length >= 6,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
            ) {
                if (busy) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White)
                else Text(if (registerMode) "إنشاء الحساب" else "دخول")
            }
        }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                TextButton(onClick = { registerMode = !registerMode }) {
                    Text(if (registerMode) "لديك حساب؟ سجّلي الدخول" else "ليس لديك حساب؟ أنشئي حسابًا")
                }
            }
        }
        if (!registerMode) {
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                    TextButton(onClick = {
                        if (busy) return@TextButton
                        if (email.trim().isBlank()) {
                            message = "أدخلي البريد الإلكتروني أولًا"
                            return@TextButton
                        }
                        busy = true
                        message = ""
                        scope.launch {
                            runCatching { app.account.resetPassword(email.trim()) }
                                .onSuccess { message = "تم إرسال رابط تغيير كلمة المرور إلى بريدك الإلكتروني. تفقدي البريد الوارد والرسائل غير المرغوب فيها." }
                                .onFailure { message = it.message ?: "تعذر الإرسال" }
                            busy = false
                        }
                    }, enabled = !busy) { Text(if (busy) "جاري إرسال الرابط..." else "نسيت كلمة المرور") }
                }
            }
        }
    }
}
