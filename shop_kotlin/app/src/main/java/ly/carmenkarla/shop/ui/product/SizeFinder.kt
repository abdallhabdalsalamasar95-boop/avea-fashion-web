package ly.carmenkarla.shop.ui.product

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import ly.carmenkarla.shop.ui.theme.Brand

/** Same weight-to-size mapping the storefront uses, so both surfaces recommend identically. */
private val SIZE_CHART = listOf(
    45 to "36",
    52 to "38",
    59 to "40",
    67 to "42",
    75 to "44",
    84 to "46",
    93 to "48",
    Int.MAX_VALUE to "50",
)

private fun sizeForWeight(kg: Int): String =
    SIZE_CHART.first { kg <= it.first }.second

@Composable
fun SizeFinder(availableSizes: List<String>, onPick: (String) -> Unit) {
    var weight by remember { mutableStateOf("") }
    val kg = weight.trim().toIntOrNull()
    val suggested = kg?.takeIf { it in 30..200 }?.let { sizeForWeight(it) }
    val inStock = suggested != null && availableSizes.contains(suggested)

    Column(
        Modifier
            .fillMaxWidth()
            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text("مش متأكدة من مقاسك؟", style = MaterialTheme.typography.titleSmall)
        Text(
            "اكتبي وزنك ونقترح لك المقاس المناسب",
            style = MaterialTheme.typography.labelSmall,
            color = Brand.Muted,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = weight,
                onValueChange = { value -> weight = value.filter { it.isDigit() }.take(3) },
                label = { Text("الوزن بالكيلو") },
                singleLine = true,
                shape = RoundedCornerShape(10.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.width(150.dp),
            )
            if (suggested != null) {
                Spacer(Modifier.width(12.dp))
                Column {
                    Text("المقاس المقترح", style = MaterialTheme.typography.labelSmall, color = Brand.Muted)
                    Text(
                        suggested,
                        style = MaterialTheme.typography.headlineSmall,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }

        if (suggested != null && !inStock) {
            Text(
                "المقاس $suggested غير متوفر حاليًا في هذا الموديل",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.error,
            )
        }
        if (suggested != null && inStock) {
            OutlinedButton(
                onClick = { onPick(suggested) },
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("اختيار المقاس $suggested") }
        }
        Text(
            "الاقتراح تقريبي — راجعي جدول المقاسات إذا كانت القصّة ضيقة أو واسعة.",
            style = MaterialTheme.typography.labelSmall,
            color = Brand.Muted,
        )
    }
}
