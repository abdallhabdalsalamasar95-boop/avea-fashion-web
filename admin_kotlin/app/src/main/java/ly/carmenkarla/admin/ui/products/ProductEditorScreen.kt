package ly.carmenkarla.admin.ui.products

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.COMMON_COLORS
import ly.carmenkarla.admin.data.SizeCatalog
import ly.carmenkarla.admin.ui.LabeledField
import ly.carmenkarla.admin.ui.LoadingBox
import ly.carmenkarla.admin.ui.SwitchRow

/** Drops the trailing ".0" so prices show as 480 rather than 480.0 while keeping real decimals. */
private fun trimNumber(value: Double): String =
    if (value == value.toLong().toDouble()) value.toLong().toString() else value.toString()

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProductEditorScreen(productId: String?, onDone: () -> Unit, onBack: () -> Unit) {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()

    var loading by remember { mutableStateOf(productId != null) }
    var saving by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    var confirmDelete by remember { mutableStateOf(false) }

    var name by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var price by remember { mutableStateOf("") }
    var oldPrice by remember { mutableStateOf("") }
    var purchasePrice by remember { mutableStateOf("") }
    var wholesaleEnabled by remember { mutableStateOf(false) }
    var wholesalePrice by remember { mutableStateOf("") }
    var wholesaleMinQty by remember { mutableStateOf("") }
    var commission by remember { mutableStateOf("") }
    var sizeType by remember { mutableStateOf("clothing") }
    var hidden by remember { mutableStateOf(false) }
    val images = remember { mutableStateListOf<String>() }
    val colors = remember { mutableStateListOf<String>() }
    val quantities = remember { mutableStateMapOf<String, Int>() }
    val knownCategories = remember { mutableStateListOf<String>() }
    var newCategoryDialog by remember { mutableStateOf(false) }
    var newColorDialog by remember { mutableStateOf(false) }
    var newSizeDialog by remember { mutableStateOf(false) }
    var uploading by remember { mutableStateOf(false) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris: List<Uri> ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        uploading = true
        scope.launch {
            uris.forEach { uri ->
                runCatching { repository.uploadImage(uri) }
                    .onSuccess { images.add(it) }
                    .onFailure { message = it.message ?: "فشل رفع الصورة" }
            }
            uploading = false
        }
    }

    LaunchedEffect(productId) {
        val all = runCatching { repository.products() }.getOrDefault(emptyList())
        knownCategories.clear()
        knownCategories.addAll(
            all.map { it.category.trim() }.filter { it.isNotEmpty() }.distinct().sorted(),
        )

        if (productId == null) {
            loading = false
            return@LaunchedEffect
        }
        val product = all.firstOrNull { it.id == productId }
        if (product != null) {
            name = product.name
            code = product.productCode
            category = product.category
            description = product.description
            price = trimNumber(product.price)
            oldPrice = product.oldPrice.takeIf { it > 0 }?.let { trimNumber(it) }.orEmpty()
            purchasePrice = product.purchasePrice.takeIf { it > 0 }?.let { trimNumber(it) }.orEmpty()
            commission = product.commissionPercent.takeIf { it > 0 }?.let { trimNumber(it) }.orEmpty()
            wholesaleEnabled = product.wholesaleEnabled == 1
            wholesalePrice = product.wholesalePrice.takeIf { it > 0 }?.let { trimNumber(it) }.orEmpty()
            wholesaleMinQty = product.wholesaleMinQty.takeIf { it > 1 }?.toString().orEmpty()
            sizeType = product.sizeType.ifBlank { "clothing" }
            colors.clear()
            colors.addAll(product.colors)
            hidden = product.isHidden == 1
            images.clear()
            buildList {
                if (product.imageUrl.isNotBlank()) add(product.imageUrl)
                addAll(product.imageUrls)
            }.distinct().forEach { images.add(repository.absoluteUrl(it)) }
            quantities.clear()
            product.sizeQuantities.forEach { (size, qty) -> quantities[size] = qty }
            product.sizes.forEach { quantities.putIfAbsent(it, 0) }
        } else {
            message = "تعذر تحميل المنتج"
        }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (productId == null) "منتج جديد" else "تعديل المنتج") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "رجوع") }
                },
                actions = {
                    if (productId != null) {
                        IconButton(onClick = { confirmDelete = true }) {
                            Icon(Icons.Default.Delete, "حذف", tint = MaterialTheme.colorScheme.error)
                        }
                    }
                },
            )
        },
    ) { padding ->
        if (loading) {
            Box(Modifier.padding(padding)) { LoadingBox() }
            return@Scaffold
        }

        Column(
            Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SectionTitle("الصور")
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(images.toList()) { url ->
                    Box {
                        AsyncImage(
                            model = url,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(width = 86.dp, height = 110.dp)
                                .clip(RoundedCornerShape(10.dp)),
                        )
                        IconButton(
                            onClick = { images.remove(url) },
                            modifier = Modifier.align(Alignment.TopEnd),
                        ) {
                            Icon(
                                Icons.Default.Close,
                                "حذف الصورة",
                                tint = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
                item {
                    Box(
                        Modifier
                            .size(width = 86.dp, height = 110.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                            .clickable(enabled = !uploading) { picker.launch("image/*") },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (uploading) CircularProgressIndicator(Modifier.size(22.dp))
                        else Icon(Icons.Default.Add, "إضافة صورة")
                    }
                }
            }
            Text(
                "الصورة الأولى هي الصورة الرئيسية",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            SectionTitle("البيانات الأساسية")
            LabeledField("اسم المنتج", name, { name = it })
            LabeledField("رمز المنتج", code, { code = it }, placeholder = "يُولَّد تلقائيًا إن تُرك فارغًا")

            Text("القسم", style = MaterialTheme.typography.labelLarge)
            FlowChips {
                knownCategories.forEach { option ->
                    FilterChip(
                        selected = category == option,
                        onClick = { category = option },
                        label = { Text(option) },
                    )
                }
                OutlinedButton(onClick = { newCategoryDialog = true }) { Text("+ قسم جديد") }
            }
            if (category.isBlank()) {
                Text(
                    "اختاري قسمًا أو أنشئي قسمًا جديدًا",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            LabeledField("الوصف", description, { description = it }, singleLine = false, minLines = 3)

            SectionTitle("السعر والعمولة")
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                LabeledField("السعر (د.ل)", price, { price = it }, Modifier.weight(1f))
                LabeledField("قبل الخصم", oldPrice, { oldPrice = it }, Modifier.weight(1f))
            }
            LabeledField(
                "سعر الشراء (د.ل)",
                purchasePrice,
                { purchasePrice = it },
                placeholder = "مطلوب لحساب الأرباح بدقة",
            )
            val sellValue = price.trim().toDoubleOrNull() ?: 0.0
            val costValue = purchasePrice.trim().toDoubleOrNull() ?: 0.0
            if (sellValue > 0 && costValue > 0) {
                val margin = sellValue - costValue
                Text(
                    "ربحك من القطعة: ${trimNumber(margin)} د.ل (${((margin / sellValue) * 100).toInt()}%)",
                    style = MaterialTheme.typography.labelMedium,
                    color = if (margin > 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                )
            }
            LabeledField("عمولة المندوب %", commission, { commission = it }, placeholder = "اتركه فارغًا للنسبة الافتراضية")

            SectionTitle("الجملة")
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("إتاحة هذه القطعة بالجملة", style = MaterialTheme.typography.titleSmall)
                    Text(
                        "تظهر في قسم الجملة ويُطبّق السعر تلقائيًا عند الحد الأدنى",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(checked = wholesaleEnabled, onCheckedChange = { wholesaleEnabled = it })
            }
            if (wholesaleEnabled) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    LabeledField("سعر الجملة (د.ل)", wholesalePrice, { wholesalePrice = it }, Modifier.weight(1f))
                    LabeledField("الحد الأدنى للكمية", wholesaleMinQty, { wholesaleMinQty = it }, Modifier.weight(1f))
                }
                val bulkValue = wholesalePrice.trim().toDoubleOrNull() ?: 0.0
                if (bulkValue > 0 && costValue > 0) {
                    val bulkMargin = bulkValue - costValue
                    Text(
                        "ربحك في الجملة: ${trimNumber(bulkMargin)} د.ل للقطعة",
                        style = MaterialTheme.typography.labelMedium,
                        color = if (bulkMargin > 0) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                    )
                }
                if (bulkValue > 0 && sellValue > 0 && bulkValue >= sellValue) {
                    Text(
                        "سعر الجملة لازم يكون أقل من سعر القطعة",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            SectionTitle("نوع المقاسات")
            FlowChips {
                SizeCatalog.types.forEach { (key, label) ->
                    FilterChip(
                        selected = sizeType == key,
                        onClick = {
                            if (sizeType != key) {
                                sizeType = key
                                quantities.clear()
                            }
                        },
                        label = { Text(label) },
                    )
                }
            }

            SectionTitle("المقاسات والكميات")
            if (quantities.isEmpty()) {
                Text(
                    "لا توجد مقاسات مضافة بعد",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            quantities.keys.toList().forEach { size ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { quantities.remove(size) }) {
                        Icon(Icons.Default.Close, "إلغاء المقاس", tint = MaterialTheme.colorScheme.error)
                    }
                    Text(
                        size,
                        style = MaterialTheme.typography.titleSmall,
                        modifier = Modifier.width(56.dp),
                    )
                    OutlinedButton(onClick = {
                        quantities[size] = (quantities[size] ?: 0) - 1
                    }, enabled = (quantities[size] ?: 0) > 0) { Text("−") }
                    Text(
                        "  ${quantities[size] ?: 0}  ",
                        style = MaterialTheme.typography.titleMedium,
                    )
                    OutlinedButton(onClick = {
                        quantities[size] = (quantities[size] ?: 0) + 1
                    }) { Text("+") }
                }
            }
            Text(
                "إجمالي القطع: ${quantities.values.sum()}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
            )

            val remainingSizes = SizeCatalog.sizesFor(sizeType).filterNot { quantities.containsKey(it) }
            if (remainingSizes.isNotEmpty()) {
                Text(
                    "إضافة مقاس",
                    style = MaterialTheme.typography.labelLarge,
                )
                FlowChips {
                    remainingSizes.forEach { size ->
                        FilterChip(
                            selected = false,
                            onClick = { quantities[size] = 0 },
                            label = { Text(size) },
                        )
                    }
                    OutlinedButton(onClick = { newSizeDialog = true }) { Text("+ مقاس آخر") }
                }
            } else {
                OutlinedButton(onClick = { newSizeDialog = true }) { Text("+ مقاس آخر") }
            }

            SectionTitle("الألوان")
            FlowChips {
                (COMMON_COLORS + colors.filterNot { it in COMMON_COLORS }).forEach { option ->
                    FilterChip(
                        selected = colors.contains(option),
                        onClick = { if (colors.contains(option)) colors.remove(option) else colors.add(option) },
                        label = { Text(option) },
                    )
                }
                OutlinedButton(onClick = { newColorDialog = true }) { Text("+ لون جديد") }
            }

            SectionTitle("الظهور")
            SwitchRow("إخفاء المنتج من المتجر", hidden) { hidden = it }

            if (message.isNotEmpty()) {
                Text(message, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }

            Spacer(Modifier.height(4.dp))
            Button(
                onClick = {
                    if (name.isBlank()) {
                        message = "أدخل اسم المنتج"
                        return@Button
                    }
                    saving = true
                    message = ""
                    scope.launch {
                        val payload = repository.productPayload(
                            id = productId.orEmpty(),
                            name = name.trim(),
                            productCode = code.trim(),
                            category = category.trim().ifBlank { "غير مصنف" },
                            description = description.trim(),
                            price = price.trim().toDoubleOrNull() ?: 0.0,
                            oldPrice = oldPrice.trim().toDoubleOrNull() ?: 0.0,
                            purchasePrice = purchasePrice.trim().toDoubleOrNull() ?: 0.0,
                            commissionPercent = commission.trim().toDoubleOrNull() ?: 0.0,
                            wholesaleEnabled = wholesaleEnabled,
                            wholesalePrice = wholesalePrice.trim().toDoubleOrNull() ?: 0.0,
                            wholesaleMinQty = wholesaleMinQty.trim().toIntOrNull() ?: 0,
                            images = images.toList(),
                            sizeType = sizeType,
                            sizeQuantities = quantities.toMap(),
                            colors = colors.toList(),
                            isHidden = hidden,
                        )
                        runCatching { repository.saveProduct(productId.orEmpty(), payload) }
                            .onSuccess { onDone() }
                            .onFailure { message = it.message ?: "تعذر حفظ المنتج" }
                        saving = false
                    }
                },
                enabled = !saving && !uploading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (saving) CircularProgressIndicator(Modifier.size(20.dp)) else Text("حفظ")
            }
            Spacer(Modifier.height(24.dp))
        }
    }

    if (confirmDelete && productId != null) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("حذف المنتج") },
            text = { Text("سيُحذف المنتج نهائيًا. هل أنت متأكد؟") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    scope.launch {
                        runCatching { repository.deleteProduct(productId) }
                            .onSuccess { onDone() }
                            .onFailure { message = it.message ?: "تعذر الحذف" }
                    }
                }) { Text("حذف", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("إلغاء") } },
        )
    }

    if (newCategoryDialog) {
        TextPromptDialog(
            title = "قسم جديد",
            placeholder = "مثال: فساتين سهرة",
            onDismiss = { newCategoryDialog = false },
            onConfirm = { value ->
                if (value.isNotBlank()) {
                    if (!knownCategories.contains(value)) knownCategories.add(value)
                    category = value
                }
                newCategoryDialog = false
            },
        )
    }

    if (newColorDialog) {
        TextPromptDialog(
            title = "لون جديد",
            placeholder = "مثال: أزرق سماوي",
            onDismiss = { newColorDialog = false },
            onConfirm = { value ->
                if (value.isNotBlank() && !colors.contains(value)) colors.add(value)
                newColorDialog = false
            },
        )
    }

    if (newSizeDialog) {
        TextPromptDialog(
            title = "مقاس جديد",
            placeholder = "مثال: XL",
            onDismiss = { newSizeDialog = false },
            onConfirm = { value ->
                val trimmed = value.trim()
                if (trimmed.isNotBlank() && !quantities.containsKey(trimmed)) quantities[trimmed] = 0
                newSizeDialog = false
            },
        )
    }
}

@Composable
private fun TextPromptDialog(
    title: String,
    placeholder: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var value by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { LabeledField(title, value, { value = it }, placeholder = placeholder) },
        confirmButton = { TextButton(onClick = { onConfirm(value.trim()) }) { Text("إضافة") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("إلغاء") } },
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FlowChips(content: @Composable () -> Unit) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) { content() }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 6.dp),
    )
}
