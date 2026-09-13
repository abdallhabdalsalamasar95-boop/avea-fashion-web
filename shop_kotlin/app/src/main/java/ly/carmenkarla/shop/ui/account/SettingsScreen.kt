package ly.carmenkarla.shop.ui.account

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.outlined.DeleteForever
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.PrivacyTip
import androidx.compose.material.icons.outlined.SupportAgent
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import ly.carmenkarla.shop.ShopApp
import ly.carmenkarla.shop.ui.openSupportChat
import ly.carmenkarla.shop.ui.theme.Brand

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    onOpenPrivacy: () -> Unit,
    onOpenTerms: () -> Unit,
) {
    val app = ShopApp.instance
    val context = LocalContext.current
    var editDetails by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val version = remember {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName.orEmpty()
        }.getOrDefault("")
    }
    val details = app.customer.value

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("الإعدادات") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "رجوع")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { GroupLabel("بياناتي") }
                item {
                    SettingsGroup(
                        listOf(
                            SettingsRow(
                                Icons.Outlined.LocationOn,
                                "بيانات التوصيل",
                                listOf(details.city, details.area, details.address)
                                    .filter { it.isNotBlank() }
                                    .joinToString(" · ")
                                    .ifBlank { "لم تُحفظ بعد" },
                            ) { editDetails = true },
                        ),
                    )
                }

                item { GroupLabel("المساعدة") }
                item {
                    SettingsGroup(
                        listOf(
                            SettingsRow(
                                Icons.Outlined.SupportAgent,
                                "تواصلي مع الدعم",
                                "واتساب · رد سريع",
                            ) {
                                openSupportChat(context, "مرحبًا، أحتاج مساعدة من متجر Carmen Karla")
                            },
                            SettingsRow(
                                Icons.Outlined.Language,
                                "زيارة الموقع",
                                "carmen karla على الإنترنت",
                            ) { openLink(context, "$STOREFRONT/") },
                        ),
                    )
                }

                item { GroupLabel("قانوني") }
                item {
                    SettingsGroup(
                        listOf(
                            SettingsRow(
                                Icons.Outlined.PrivacyTip,
                                "سياسة الخصوصية",
                                "كيف نتعامل مع بياناتك",
                                onOpenPrivacy,
                            ),
                            SettingsRow(
                                Icons.Outlined.Description,
                                "الشروط والأحكام",
                                "الطلب والتوصيل والاسترجاع",
                                onOpenTerms,
                            ),
                            SettingsRow(Icons.Outlined.Info, "عن التطبيق", "الإصدار $version", null),
                        ),
                    )
                }

                item {
                    Text(
                        "CARMEN KARLA",
                        Modifier
                            .fillMaxWidth()
                            .padding(top = 16.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = Brand.Muted,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                }

                if (app.account.user != null) {
                    item { GroupLabel("منطقة الخطر") }
                    item {
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .border(
                                    1.dp,
                                    MaterialTheme.colorScheme.error.copy(alpha = 0.4f),
                                    RoundedCornerShape(12.dp),
                                )
                                .clickable { confirmDelete = true }
                                .padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center,
                        ) {
                            Icon(
                                Icons.Outlined.DeleteForever,
                                null,
                                Modifier.size(18.dp),
                                tint = MaterialTheme.colorScheme.error,
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                "حذف حسابي نهائيًا",
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
            }
        }
    }

    if (editDetails) {
        DetailsDialog(onDismiss = { editDetails = false })
    }

    if (confirmDelete) {
        DeleteAccountDialog(onDismiss = { confirmDelete = false })
    }
}

@Composable
private fun DeleteAccountDialog(onDismiss: () -> Unit) {
    val app = ShopApp.instance
    val scope = rememberCoroutineScope()
    var password by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val canUsePassword = app.account.hasPasswordProvider

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("حذف الحساب نهائيًا") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "سيُحذف حسابك ومفضلاتك وسلتك نهائيًا ولا يمكن التراجع. " +
                        "طلباتك السابقة تبقى لدى المتجر لأغراض المحاسبة.",
                    style = MaterialTheme.typography.bodySmall,
                )
                if (canUsePassword) {
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = { Text("أكدّي كلمة المرور") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    Text(
                        "حسابك مسجل عبر Google، فتواصلي مع الدعم لحذف الحساب.",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
                if (error.isNotEmpty()) {
                    Text(
                        error,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = canUsePassword && !busy && password.length >= 6,
                onClick = {
                    busy = true
                    error = ""
                    scope.launch {
                        runCatching { app.account.deleteAccount(password) }
                            .onSuccess {
                                app.clearAfterAccountDeletion()
                                onDismiss()
                            }
                            .onFailure { error = it.message ?: "تعذر حذف الحساب" }
                        busy = false
                    }
                },
            ) {
                Text(
                    if (busy) "جارٍ الحذف..." else "حذف نهائي",
                    color = MaterialTheme.colorScheme.error,
                )
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("تراجع") } },
    )
}

data class SettingsRow(
    val icon: ImageVector,
    val title: String,
    val subtitle: String,
    val onClick: (() -> Unit)?,
)

@Composable
fun SettingsGroup(rows: List<SettingsRow>) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(12.dp)),
    ) {
        rows.forEachIndexed { index, row ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .then(if (row.onClick != null) Modifier.clickable(onClick = row.onClick) else Modifier)
                    .padding(horizontal = 12.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    Modifier
                        .size(32.dp)
                        .clip(RoundedCornerShape(9.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(row.icon, null, Modifier.size(17.dp), tint = Brand.Ink)
                }
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
                        .padding(start = 55.dp)
                        .height(1.dp)
                        .background(MaterialTheme.colorScheme.outline),
                )
            }
        }
    }
}

@Composable
private fun GroupLabel(text: String) {
    Text(
        text,
        Modifier.padding(start = 4.dp),
        style = MaterialTheme.typography.labelSmall,
        color = Brand.Muted,
    )
}
