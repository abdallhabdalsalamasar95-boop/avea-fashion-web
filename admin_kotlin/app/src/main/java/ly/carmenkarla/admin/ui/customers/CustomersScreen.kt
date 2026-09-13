package ly.carmenkarla.admin.ui.customers

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import ly.carmenkarla.admin.AdminApp
import ly.carmenkarla.admin.data.Customer
import ly.carmenkarla.admin.data.CustomersResponse
import ly.carmenkarla.admin.ui.ErrorBox
import ly.carmenkarla.admin.ui.LoadingBox
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

private enum class CustomerTab(val label: String) {
    Active("النشطون"),
    Repeat("متكررون"),
    All("الكل"),
    Dormant("متوقفون"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomersScreen(onBack: () -> Unit) {
    val repository = AdminApp.instance.repository

    var data by remember { mutableStateOf<CustomersResponse?>(null) }
    var error by remember { mutableStateOf("") }
    var reload by remember { mutableStateOf(0) }
    var tab by remember { mutableStateOf(CustomerTab.Active) }
    var query by remember { mutableStateOf("") }

    LaunchedEffect(reload) {
        error = ""
        data = null
        runCatching { repository.customers() }
            .onSuccess { data = it }
            .onFailure { error = it.message ?: "تعذر تحميل العملاء" }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("العملاء") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "رجوع") }
                },
            )
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {

    when {
        error.isNotEmpty() -> ErrorBox(error, { reload++ })
        data == null -> LoadingBox()
        else -> {
            val all = data!!.items
            val filtered = all
                .filter { customer ->
                    when (tab) {
                        CustomerTab.Active -> customer.active
                        CustomerTab.Repeat -> customer.repeat
                        CustomerTab.Dormant -> !customer.active
                        CustomerTab.All -> true
                    }
                }
                .filter { customer ->
                    val term = query.trim()
                    term.isEmpty() ||
                        customer.name.contains(term, true) ||
                        customer.phone.contains(term) ||
                        customer.city.contains(term, true)
                }

            Column(Modifier.fillMaxSize()) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Stat("${data!!.activeCount}", "نشط", Modifier.weight(1f))
                    Stat("${data!!.repeatCount}", "متكرر", Modifier.weight(1f))
                    Stat("${data!!.count}", "الإجمالي", Modifier.weight(1f))
                }

                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text("ابحث بالاسم أو الهاتف أو المدينة") },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp),
                )

                Row(
                    Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    CustomerTab.entries.forEach { entry ->
                        val count = all.count {
                            when (entry) {
                                CustomerTab.Active -> it.active
                                CustomerTab.Repeat -> it.repeat
                                CustomerTab.Dormant -> !it.active
                                CustomerTab.All -> true
                            }
                        }
                        FilterChip(
                            selected = tab == entry,
                            onClick = { tab = entry },
                            label = { Text("${entry.label} ($count)") },
                        )
                    }
                }

                if (filtered.isEmpty()) {
                    Column(
                        Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) { Text("لا يوجد عملاء في هذا التصنيف") }
                    return@Column
                }

                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(filtered, key = { it.phone }) { customer -> CustomerCard(customer) }
                }
            }
        }
    }
        }
    }
}

@Composable
private fun Stat(value: String, label: String, modifier: Modifier = Modifier) {
    Card(modifier) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(value, style = MaterialTheme.typography.titleLarge)
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun CustomerCard(customer: Customer) {
    val clipboard = LocalClipboardManager.current
    val lastSeen = remember(customer.lastOrderMs) { relativeDays(customer.lastOrderMs) }

    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        customer.name.ifBlank { "بدون اسم" },
                        style = MaterialTheme.typography.titleSmall,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        listOf(customer.phone, customer.city).filter { it.isNotBlank() }.joinToString(" · "),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Icon(
                    Icons.Default.ContentCopy,
                    "نسخ الرقم",
                    Modifier
                        .size(18.dp)
                        .clickable { clipboard.setText(AnnotatedString(customer.phone)) },
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Pill("${customer.ordersCount} طلب")
                if (customer.deliveredCount > 0) Pill("${customer.deliveredCount} موصّل")
                if (customer.canceledCount > 0) Pill("${customer.canceledCount} ملغي")
                if (customer.openCount > 0) Pill("${customer.openCount} جاري")
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "أنفق ${"%.0f".format(customer.totalSpent)} د.ل",
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    lastSeen,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (customer.address.isNotBlank()) {
                Text(
                    customer.address,
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun Pill(text: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)) {
        Text(
            text,
            Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
            style = MaterialTheme.typography.labelSmall,
        )
    }
}

private fun relativeDays(ms: Long): String {
    if (ms <= 0) return ""
    val days = TimeUnit.MILLISECONDS.toDays(System.currentTimeMillis() - ms)
    return when {
        days <= 0L -> "آخر طلب اليوم"
        days == 1L -> "آخر طلب أمس"
        days < 30L -> "آخر طلب قبل $days يوم"
        else -> "آخر طلب ${SimpleDateFormat("dd/MM/yyyy", Locale("ar")).format(Date(ms))}"
    }
}
