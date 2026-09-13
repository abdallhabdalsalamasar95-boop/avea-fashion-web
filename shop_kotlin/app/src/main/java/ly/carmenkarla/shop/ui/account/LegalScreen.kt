package ly.carmenkarla.shop.ui.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import ly.carmenkarla.shop.ui.theme.Brand

data class LegalSection(val heading: String, val body: String)

/** Mirrors the storefront's legal pages so nothing opens an external browser. */
object LegalContent {
    const val UPDATED = "آخر تحديث: أغسطس 2026"

    val privacy = listOf(
        LegalSection(
            "",
            "نحترم خصوصيتك ونستخدم بيانات الاسم والهاتف والعنوان فقط لإدارة حسابك " +
                "وتنفيذ طلباتك وتقديم الدعم.",
        ),
        LegalSection(
            "البيانات التي نجمعها",
            "بيانات الحساب والتوصيل، تفاصيل الطلب، والمنتجات المحفوظة. " +
                "لا نخزّن بيانات بطاقات الدفع داخل التطبيق.",
        ),
        LegalSection(
            "حماية البيانات",
            "تُدار الحسابات عبر Firebase وتُطبق قواعد وصول تمنع قراءة بيانات المستخدم " +
                "إلا من صاحب الحساب أو الإدارة المخولة.",
        ),
        LegalSection(
            "الزوار",
            "نحسب عدد المتصفحين في الوقت الحالي برقم مجهول فقط، بدون أي بيانات شخصية.",
        ),
        LegalSection(
            "التواصل",
            "يمكنك طلب تحديث أو حذف بياناتك بالتواصل مع خدمة العملاء عبر واتساب.",
        ),
    )

    val terms = listOf(
        LegalSection(
            "",
            "باستخدام متجر كارمن كارلا فإنك توافقين على هذه الشروط المتعلقة " +
                "بالطلب والتوصيل والاسترجاع.",
        ),
        LegalSection(
            "الطلبات والأسعار",
            "تخضع الطلبات لتأكيد المخزون. الأسعار المعروضة بالدينار الليبي، " +
                "ويضاف سعر التوصيل بحسب المدينة قبل تأكيد الطلب.",
        ),
        LegalSection(
            "التوصيل والاسترجاع",
            "يتواصل فريقنا لتأكيد الطلب وموعد التوصيل. يجب الإبلاغ عن أي مشكلة " +
                "في المنتج فور الاستلام وفق سياسة المتجر.",
        ),
        LegalSection(
            "الدفع",
            "الدفع عند الاستلام لجميع المدن الليبية عبر شركة التوصيل المعتمدة.",
        ),
        LegalSection(
            "الحساب",
            "المستخدمة مسؤولة عن حماية بيانات دخولها وعن صحة معلومات التوصيل المسجلة.",
        ),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LegalScreen(title: String, sections: List<LegalSection>, onBack: () -> Unit) {
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(title) },
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
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                items(sections) { section ->
                    Column(
                        Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        if (section.heading.isNotBlank()) {
                            Text(section.heading, style = MaterialTheme.typography.titleMedium)
                        }
                        Text(
                            section.body,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                    }
                }
                item {
                    Text(
                        LegalContent.UPDATED,
                        style = MaterialTheme.typography.labelSmall,
                        color = Brand.Muted,
                    )
                }
            }
        }
    }
}
