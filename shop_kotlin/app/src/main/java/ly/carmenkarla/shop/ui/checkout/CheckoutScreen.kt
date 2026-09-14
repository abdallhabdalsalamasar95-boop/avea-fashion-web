package ly.carmenkarla.shop.ui.checkout

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import kotlinx.coroutines.launch
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.ui.formatMoney

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CheckoutScreen(onBack: () -> Unit, onDone: () -> Unit) {
    val app = ShopApp.instance
    val scope = rememberCoroutineScope()
    val isAmbassadorOrder = app.activeAmbassador != null

    // In customer mode, prefill saved details. In ambassador mode, start with clean client fields.
    var name by remember { mutableStateOf(if (isAmbassadorOrder) "" else app.customer.value.name) }
    var phone by remember { mutableStateOf(if (isAmbassadorOrder) "" else app.customer.value.phone) }
    var city by remember { mutableStateOf(if (isAmbassadorOrder) "" else app.customer.value.city) }
    var area by remember { mutableStateOf(if (isAmbassadorOrder) "" else app.customer.value.area) }
    var address by remember { mutableStateOf(if (isAmbassadorOrder) "" else app.customer.value.address) }
    var note by remember { mutableStateOf("") }

    var destinations by remember { mutableStateOf<Map<String, List<String>>>(emptyMap()) }
    var search by remember { mutableStateOf("") }
    var shipping by remember { mutableStateOf(0.0) }
    var shippingLoading by remember { mutableStateOf(false) }
    var sending by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    var placedOrderId by remember { mutableStateOf("") }

    LaunchedEffect(app.deliveryDestinations) {
        destinations = app.deliveryDestinations
        app.refreshDeliveryDestinations()
    }

    if (placedOrderId.isNotEmpty()) {
        OrderPlaced(placedOrderId, onDone)
        return
    }

    val subtotal = app.cartSubtotal

    LaunchedEffect(city, area) {
        if (city.isBlank()) {
            shipping = 0.0
            shippingLoading = false
            return@LaunchedEffect
        }
        shippingLoading = true
        shipping = app.repository.shippingFor(city, area, address)
        shippingLoading = false
    }
    val matches = remember(search, destinations) {
        val term = search.trim()
        if (term.length < 2) emptyList()
        else destinations.flatMap { (c, areas) -> areas.map { c to it } }
            .filter { (c, a) -> a.contains(term) || c.contains(term) }
            .take(8)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isAmbassadorOrder) "إتمام الطلب (وضع المندوبة)" else "إتمام الطلب") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "رجوع") } },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (isAmbassadorOrder) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = androidx.compose.material3.CardDefaults.cardColors(
                        containerColor = ly.carmenkarla.shop.ui.theme.Brand.RoseSoft,
                    ),
                ) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            "طلب مسجّل باسم المندوبة ${app.activeAmbassador?.ambassadorName ?: ""}",
                            style = MaterialTheme.typography.titleSmall,
                            color = ly.carmenkarla.shop.ui.theme.Brand.RoseDark,
                            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                        )
                        Text(
                            "أدخلي بيانات العميلة المستلمة. لن يتم تغيير بيانات ملفكِ الشخصي المحفوظ.",
                            style = MaterialTheme.typography.bodySmall,
                            color = ly.carmenkarla.shop.ui.theme.Brand.Ink,
                        )
                    }
                }
            }

            Text(
                if (isAmbassadorOrder) "بيانات العميلة والتوصيل" else "بيانات التوصيل",
                style = MaterialTheme.typography.titleMedium,
            )

            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("الاسم الكامل") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = phone,
                onValueChange = { phone = it },
                label = { Text("رقم الهاتف") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                modifier = Modifier.fillMaxWidth(),
            )

            OutlinedTextField(
                value = search,
                onValueChange = { search = it },
                label = { Text("ابحثي عن مدينتك أو منطقتك") },
                placeholder = { Text("مثال: زليتن أو سلوق") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            if (matches.isNotEmpty()) {
                Card(Modifier.fillMaxWidth()) {
                    Column {
                        matches.forEach { (c, a) ->
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        city = c
                                        area = a
                                        search = ""
                                    }
                                    .padding(12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Text(a, style = MaterialTheme.typography.bodyMedium)
                                Text(
                                    c,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }

            if (city.isNotBlank()) {
                Card(Modifier.fillMaxWidth()) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text("الوجهة", style = MaterialTheme.typography.labelMedium)
                        Text("$city — $area", style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }

            OutlinedTextField(
                value = address,
                onValueChange = { address = it },
                label = { Text("العنوان بالتفصيل") },
                placeholder = { Text("الشارع، رقم المنزل، أقرب نقطة دالة") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("ملاحظة (اختياري)") },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 80.dp),
            )

            HorizontalDivider()

            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("مراجعة الطلب", style = MaterialTheme.typography.titleSmall)
                    app.cart.forEach { line ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(
                                "${line.name} ${line.size} ×${line.quantity}",
                                style = MaterialTheme.typography.labelMedium,
                            )
                            Text(formatMoney(line.lineTotal), style = MaterialTheme.typography.labelMedium)
                        }
                    }
                    HorizontalDivider()
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("المجموع")
                        Text(formatMoney(subtotal))
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        val destinationLabel = area.trim().ifBlank { city }
                        Text(if (city.isBlank()) "التوصيل" else "التوصيل إلى $destinationLabel")
                        Text(
                            when {
                                city.isBlank() -> "—"
                                shippingLoading -> "جاري الحساب..."
                                else -> formatMoney(shipping)
                            },
                        )
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("إجمالي المنتجات", style = MaterialTheme.typography.titleSmall)
                        Text(
                            formatMoney(subtotal),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                    if (isAmbassadorOrder) {
                        val estimatedComm = app.cart.sumOf { line ->
                            app.commission.amountFor(
                                ly.carmenkarla.shop.data.Product(
                                    id = line.productId,
                                    price = line.unitPrice,
                                    commissionPercent = if (line.usesWholesale) 0.0 else -1.0,
                                ),
                                line.quantity,
                            )
                        }
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(
                                "عمولتك المتوقعة",
                                style = MaterialTheme.typography.labelSmall,
                                color = ly.carmenkarla.shop.ui.theme.Brand.RoseDark,
                            )
                            Text(
                                "${formatMoney(estimatedComm)} (تُعتمد بعد التوصيل)",
                                style = MaterialTheme.typography.labelSmall,
                                color = ly.carmenkarla.shop.ui.theme.Brand.RoseDark,
                                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                            )
                        }
                    }
                    Text(
                        "الدفع عند الاستلام",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }

            if (error.isNotEmpty()) {
                Text(error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }

            Button(
                onClick = {
                    error = when {
                        name.isBlank() -> "أدخلي الاسم الكامل"
                        phone.length < 8 -> "أدخلي رقم هاتف صحيح"
                        city.isBlank() -> "اختاري المدينة من القائمة"
                        area.isBlank() -> "اختاري المنطقة من القائمة"
                        address.isBlank() -> "أدخلي العنوان بالتفصيل"
                        else -> ""
                    }
                    if (error.isNotEmpty()) return@Button

                    sending = true
                    scope.launch {
                        val details = ly.carmenkarla.shop.data.CustomerDetails(
                            name = name.trim(),
                            phone = phone.trim(),
                            city = city,
                            area = area,
                            address = address.trim(),
                        )
                        val lines = app.cart.toList()
                        val token = app.account.idToken()
                        val sharedToken = app.sharedAmbassadorToken
                        runCatching {
                            app.repository.submitOrder(
                                customer = details,
                                lines = lines,
                                note = note.trim(),
                                idToken = token,
                                uid = app.account.user?.uid.orEmpty(),
                                ambassador = app.activeAmbassador,
                                ambassadorShareToken = sharedToken,
                            )
                        }
                            .onSuccess { result ->
                                if (!isAmbassadorOrder) {
                                    app.rememberCustomer(details)
                                }
                                if (sharedToken.isNotBlank()) app.clearSharedAmbassadorToken()
                                if (!isAmbassadorOrder) {
                                    app.rememberOrder(
                                        ly.carmenkarla.shop.data.SavedOrder(
                                            orderId = result.orderId,
                                            trackingToken = result.trackingToken,
                                            total = subtotal,
                                            itemCount = lines.sumOf { it.quantity },
                                            createdAtMs = System.currentTimeMillis(),
                                            summary = lines.joinToString("، ") { it.name },
                                            city = details.city,
                                            address = listOf(details.area, details.address)
                                                .filter { it.isNotBlank() }
                                                .joinToString(" · "),
                                            shipping = shipping,
                                            items = lines.map {
                                                ly.carmenkarla.shop.data.SavedOrderLine(
                                                    productId = it.productId,
                                                    productCode = it.productCode,
                                                    name = it.name,
                                                    imageUrl = it.imageUrl,
                                                    size = it.size,
                                                    color = it.color,
                                                    quantity = it.quantity,
                                                    price = it.price,
                                                )
                                            }
                                        ),
                                    )
                                }
                                app.clearCart()
                                placedOrderId = result.orderId
                            }
                            .onFailure { error = it.message ?: "تعذر إرسال الطلب" }
                        sending = false
                    }
                },
                enabled = !sending,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
            ) {
                if (sending) CircularProgressIndicator(Modifier.size(22.dp)) else Text("تأكيد الطلب")
            }
        }
    }
}

@Composable
private fun OrderPlaced(orderId: String, onDone: () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            Modifier.padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(
                Icons.Default.CheckCircle,
                null,
                Modifier.size(72.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Text("تم استلام طلبك بنجاح", style = MaterialTheme.typography.headlineSmall)
            Text("رقم الطلب", style = MaterialTheme.typography.labelMedium)
            Text(orderId, style = MaterialTheme.typography.titleMedium)
            Text(
                "سيتواصل فريقنا معكِ لتأكيد التفاصيل",
                style = MaterialTheme.typography.bodyMedium,
            )
            Button(onClick = onDone, modifier = Modifier.fillMaxWidth()) { Text("العودة للمتجر") }
        }
    }
}
