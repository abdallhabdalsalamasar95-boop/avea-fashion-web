package ly.carmenkarla.admin.ui.site

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.Announcement
import ly.carmenkarla.admin.data.HomeBanner
import ly.carmenkarla.admin.data.SectionBanner
import ly.carmenkarla.admin.data.ShippingPricing
import ly.carmenkarla.admin.data.ShippingRate
import ly.carmenkarla.admin.data.SiteSettings
import ly.carmenkarla.admin.data.WebsiteSocial
import ly.carmenkarla.admin.data.WholesaleSettings
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LabeledField
import ly.carmenkarla.admin.ui.LoadingBox
import ly.carmenkarla.admin.ui.SwitchRow

private val DefaultShippingRates = listOf(
    ShippingRate("طرابلس", "وسط طرابلس", 10.0),
    ShippingRate("طرابلس", "حي الأندلس", 10.0),
    ShippingRate("طرابلس", "تاجوراء", 12.0),
    ShippingRate("بنغازي", "وسط بنغازي", 15.0),
    ShippingRate("مصراتة", "وسط مصراتة", 12.0),
    ShippingRate("سبها", "وسط سبها", 25.0),
    ShippingRate("الزاوية", "وسط الزاوية", 10.0),
    ShippingRate("سرت", "وسط سرت", 20.0),
    ShippingRate("درنة", "وسط درنة", 25.0),
    ShippingRate("طبرق", "وسط طبرق", 30.0),
)

private val ShippingCities = listOf("طرابلس", "بنغازي", "مصراتة", "سبها", "الزاوية", "سرت", "درنة", "طبرق", "جالو وأوجلة")

@Composable
fun SiteScreen() {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()

    var settings by remember { mutableStateOf<SiteSettings?>(null) }
    var original by remember { mutableStateOf(JsonObject(emptyMap())) }
    var error by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var saving by remember { mutableStateOf(false) }
    var reload by remember { mutableStateOf(0) }

    LaunchedEffect(reload) {
        error = ""
        settings = null
        runCatching { repository.siteSettings() }
            .onSuccess {
                val loaded = it.first
                settings = loaded.copy(
                    shippingPricing = loaded.shippingPricing.copy(
                        cityRates = loaded.shippingPricing.cityRates
                            .takeIf { rates -> rates.any { it.area.isNotBlank() } }
                            ?: DefaultShippingRates,
                    ),
                )
                original = it.second
            }
            .onFailure { error = it.message ?: "تعذر تحميل إعدادات الموقع" }
    }

    when {
        error.isNotEmpty() -> ErrorBox(error, { reload++ })
        settings == null -> LoadingBox()
        else -> {
            val current = settings!!
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                AnnouncementCard(current.home.announcement) { updated ->
                    settings = current.copy(home = current.home.copy(announcement = updated))
                }

                BannerCard(
                    title = "البنر العلوي",
                    subtitle = "الصورة الكبيرة أسفل الشريط مباشرة",
                    imageUrl = current.home.banner.imageUrl,
                    altText = current.home.banner.altText,
                    linkUrl = current.home.banner.linkUrl,
                    enabled = current.home.banner.enabled,
                    onChange = { image, alt, link, on ->
                        settings = current.copy(
                            home = current.home.copy(
                                banner = HomeBanner(image, alt, link, on),
                            ),
                        )
                    },
                )

                SectionBannerCard(current.home.sectionBanner) { updated ->
                    settings = current.copy(home = current.home.copy(sectionBanner = updated))
                }

                WholesaleCard(current.wholesale) { updated ->
                    settings = current.copy(wholesale = updated)
                }

                SocialCard(current.social) { updated ->
                    settings = current.copy(social = updated)
                }

                if (message.isNotEmpty()) {
                    Text(message, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                }

                Button(
                    onClick = {
                        saving = true
                        message = ""
                        scope.launch {
                            runCatching { repository.saveSiteSettings(settings!!, original) }
                                .onSuccess { message = "تم الحفظ ✓ التغييرات تظهر بالموقع فورًا" }
                                .onFailure { message = it.message ?: "تعذر الحفظ" }
                            saving = false
                        }
                    },
                    enabled = !saving,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    if (saving) CircularProgressIndicator(Modifier.size(20.dp)) else Text("حفظ التغييرات")
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun AnnouncementCard(value: Announcement, onChange: (Announcement) -> Unit) {
    SettingsCard("الشريط العلوي", "النص المتحرك أعلى كل صفحة") {
        SwitchRow("مفعّل", value.enabled) { onChange(value.copy(enabled = it)) }
        LabeledField("النص", value.text, { onChange(value.copy(text = it)) }, singleLine = false, minLines = 2)

        Text("اللون", style = MaterialTheme.typography.labelMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("rose" to "وردي", "dark" to "أسود", "gold" to "ذهبي").forEach { (key, label) ->
                FilterChip(
                    selected = value.style == key,
                    onClick = { onChange(value.copy(style = key)) },
                    label = { Text(label) },
                )
            }
        }

        Text("سرعة الحركة: ${value.speedSeconds} ثانية", style = MaterialTheme.typography.labelMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(
                onClick = { onChange(value.copy(speedSeconds = (value.speedSeconds - 2).coerceAtLeast(6))) },
            ) { Text("أبطأ −") }
            OutlinedButton(
                onClick = { onChange(value.copy(speedSeconds = (value.speedSeconds + 2).coerceAtMost(60))) },
            ) { Text("أسرع +") }
        }
    }
}

@Composable
private fun SectionBannerCard(value: SectionBanner, onChange: (SectionBanner) -> Unit) {
    SettingsCard("بنر المنتصف", "البنر بين أقسام المنتجات") {
        SwitchRow("مفعّل", value.enabled) { onChange(value.copy(enabled = it)) }
        ImagePickerRow(value.imageUrl) { onChange(value.copy(imageUrl = it)) }
        LabeledField("وصف الصورة", value.altText, { onChange(value.copy(altText = it)) })
        LabeledField("رابط الضغط", value.linkUrl, { onChange(value.copy(linkUrl = it)) }, placeholder = "#collection")

        Text("الارتفاع", style = MaterialTheme.typography.labelMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("compact" to "صغير", "medium" to "متوسط", "large" to "كبير").forEach { (key, label) ->
                FilterChip(
                    selected = value.height == key,
                    onClick = { onChange(value.copy(height = key)) },
                    label = { Text(label) },
                )
            }
        }

        Text("العرض", style = MaterialTheme.typography.labelMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("full" to "كامل", "container" to "داخل الإطار").forEach { (key, label) ->
                FilterChip(
                    selected = value.widthMode == key,
                    onClick = { onChange(value.copy(widthMode = key)) },
                    label = { Text(label) },
                )
            }
        }
    }
}

@Composable
private fun BannerCard(
    title: String,
    subtitle: String,
    imageUrl: String,
    altText: String,
    linkUrl: String,
    enabled: Boolean,
    onChange: (String, String, String, Boolean) -> Unit,
) {
    SettingsCard(title, subtitle) {
        SwitchRow("مفعّل", enabled) { onChange(imageUrl, altText, linkUrl, it) }
        ImagePickerRow(imageUrl) { onChange(it, altText, linkUrl, enabled) }
        LabeledField("وصف الصورة", altText, { onChange(imageUrl, it, linkUrl, enabled) })
        LabeledField("رابط الضغط", linkUrl, { onChange(imageUrl, altText, it, enabled) }, placeholder = "#collection")
    }
}

@Composable
private fun WholesaleCard(value: WholesaleSettings, onChange: (WholesaleSettings) -> Unit) {
    SettingsCard("قسم الجملة", "يظهر في التطبيق والموقع للقطع المفعّلة للجملة") {
        SwitchRow("تفعيل القسم", value.enabled) { onChange(value.copy(enabled = it)) }
        LabeledField("عنوان القسم", value.title, { onChange(value.copy(title = it)) })
        LabeledField("الوصف", value.subtitle, { onChange(value.copy(subtitle = it)) })
        LabeledField(
            "ملاحظة للزبونات",
            value.note,
            { onChange(value.copy(note = it)) },
            placeholder = "مثلًا: التوصيل مجاني لطلبات الجملة",
        )
        LabeledField(
            "الحد الأدنى الافتراضي",
            value.defaultMinQty.toString(),
            { onChange(value.copy(defaultMinQty = it.trim().toIntOrNull() ?: value.defaultMinQty)) },
            placeholder = "6",
        )
        Text(
            "سعر الجملة والحد الأدنى يُضبطان لكل قطعة من شاشة تعديل المنتج.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun SocialCard(value: WebsiteSocial, onChange: (WebsiteSocial) -> Unit) {
    SettingsCard("روابط صفحاتنا", "تظهر أسفل الموقع") {
        SwitchRow("إظهار القسم", value.enabled) { onChange(value.copy(enabled = it)) }
        LabeledField("فيسبوك", value.facebook, { onChange(value.copy(facebook = it)) }, placeholder = "https://")
        LabeledField("إنستغرام", value.instagram, { onChange(value.copy(instagram = it)) }, placeholder = "https://")
        LabeledField("واتساب", value.whatsapp, { onChange(value.copy(whatsapp = it)) }, placeholder = "https://wa.me/218...")
        LabeledField("تيك توك", value.tiktok, { onChange(value.copy(tiktok = it)) }, placeholder = "https://")
        LabeledField("تيليجرام", value.telegram, { onChange(value.copy(telegram = it)) }, placeholder = "https://")
        LabeledField("الموقع", value.website, { onChange(value.copy(website = it)) }, placeholder = "https://")
        Text(
            "الروابط يجب أن تبدأ بـ https:// وإلا يتجاهلها الموقع",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun ShippingCard(value: ShippingPricing, onChange: (ShippingPricing) -> Unit) {
    var selectedCity by remember { mutableStateOf(ShippingCities.first()) }
    var cityMenuOpen by remember { mutableStateOf(false) }
    var areaName by remember { mutableStateOf("") }
    var priceText by remember { mutableStateOf("") }
    SettingsCard("أسعار التوصيل", "حددي سعر كل مدينة من داخل تطبيق لوحة التحكم") {
        Text("طريقة الحساب", style = MaterialTheme.typography.labelMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("darb" to "درب السبيل + احتياطي", "manual" to "يدوي فقط").forEach { (key, label) ->
                FilterChip(
                    selected = value.mode == key,
                    onClick = { onChange(value.copy(mode = key)) },
                    label = { Text(label) },
                )
            }
        }
        LabeledField(
            "السعر الافتراضي لباقي المدن (د.ل)",
            value.defaultCost.toString(),
            { onChange(value.copy(defaultCost = it.toDoubleOrNull()?.coerceAtLeast(0.0) ?: value.defaultCost)) },
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
            ExposedDropdownMenuBox(
                expanded = cityMenuOpen,
                onExpandedChange = { cityMenuOpen = !cityMenuOpen },
                modifier = Modifier.weight(1f),
            ) {
                androidx.compose.material3.OutlinedTextField(
                    value = selectedCity,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("المدينة") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(cityMenuOpen) },
                    modifier = Modifier.menuAnchor().fillMaxWidth(),
                )
                ExposedDropdownMenu(expanded = cityMenuOpen, onDismissRequest = { cityMenuOpen = false }) {
                    ShippingCities.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option) },
                            onClick = { selectedCity = option; cityMenuOpen = false },
                        )
                    }
                }
            }
            // The city stays as the internal branch; the operator enters the area name.
            LabeledField("اسم المنطقة", areaName, onValueChange = { areaName = it }, modifier = Modifier.weight(1.3f))
            LabeledField("السعر", priceText, onValueChange = { priceText = it }, modifier = Modifier.weight(.65f))
            Button(
                onClick = {
                    val name = areaName.trim()
                    val amount = priceText.toDoubleOrNull()
                    if (name.isNotEmpty() && amount != null && amount >= 0) {
                        onChange(value.copy(cityRates = (value.cityRates.filterNot { it.city == selectedCity && it.area == name } + ShippingRate(selectedCity, name, amount)).sortedWith(compareBy { it.city + it.area })))
                        areaName = ""
                        priceText = ""
                    }
                },
                modifier = Modifier.padding(top = 4.dp),
            ) { Icon(Icons.Default.Add, contentDescription = "إضافة مدينة") }
        }
        if (value.cityRates.isEmpty()) {
            Text("لم تتم إضافة أسعار خاصة للمدن بعد.", style = MaterialTheme.typography.bodySmall)
        } else {
            value.cityRates.forEach { rate ->
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("${rate.area.ifBlank { rate.city }} • ${rate.city}", Modifier.weight(1f))
                    Text("${"%.2f".format(rate.cost)} د.ل")
                    IconButton(onClick = { selectedCity = rate.city; areaName = rate.area.ifBlank { rate.city }; priceText = rate.cost.toString() }) {
                        Icon(Icons.Default.Edit, contentDescription = "تعديل السعر")
                    }
                    IconButton(onClick = { onChange(value.copy(cityRates = value.cityRates.filterNot { it.city == rate.city && it.area == rate.area })) }) {
                        Icon(Icons.Default.Delete, contentDescription = "حذف المدينة")
                    }
                }
            }
        }
    }
}

@Composable
private fun ImagePickerRow(imageUrl: String, onPicked: (String) -> Unit) {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()
    var uploading by remember { mutableStateOf(false) }
    var resolved by remember(imageUrl) { mutableStateOf("") }

    LaunchedEffect(imageUrl) { resolved = repository.absoluteUrl(imageUrl) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        uploading = true
        scope.launch {
            runCatching { repository.uploadImage(uri) }.onSuccess { onPicked(it) }
            uploading = false
        }
    }

    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(
            Modifier
                .size(width = 108.dp, height = 68.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .clickable(enabled = !uploading) { picker.launch("image/*") },
            contentAlignment = Alignment.Center,
        ) {
            when {
                uploading -> CircularProgressIndicator(Modifier.size(20.dp))
                resolved.isNotBlank() -> AsyncImage(
                    model = resolved,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
                else -> Icon(Icons.Default.Add, "اختيار صورة")
            }
        }
        Column {
            OutlinedButton(onClick = { picker.launch("image/*") }, enabled = !uploading) {
                Text(if (imageUrl.isBlank()) "اختيار صورة" else "تغيير الصورة")
            }
            if (imageUrl.isNotBlank()) {
                OutlinedButton(onClick = { onPicked("") }) { Text("إزالة") }
            }
        }
    }
}

@Composable
private fun SettingsCard(title: String, subtitle: String, content: @Composable () -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(
                subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            content()
        }
    }
}
