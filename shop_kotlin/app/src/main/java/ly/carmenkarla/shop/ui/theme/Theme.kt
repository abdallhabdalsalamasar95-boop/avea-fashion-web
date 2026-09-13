package ly.carmenkarla.shop.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ly.carmenkarla.shop.R

object Brand {
    val Ink = Color(0xFF141414)
    val Rose = Color(0xFF111111)
    val RoseDark = Color(0xFF111111)
    val RoseSoft = Color(0xFFF2F2F2)
    val Gold = Color(0xFF444444)
    val Muted = Color(0xFF8E8E8E)
    val Line = Color(0xFFEDEDED)
    val Canvas = Color(0xFFFFFFFF)
}

@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
private fun cairo(weight: Int) = Font(
    R.font.cairo_variable,
    FontWeight(weight),
    variationSettings = FontVariation.Settings(FontVariation.weight(weight)),
)

private val Cairo = FontFamily(cairo(400), cairo(500), cairo(600), cairo(700))

private val ShopTypography = Typography().run {
    copy(
        headlineSmall = headlineSmall.copy(fontFamily = Cairo, fontWeight = FontWeight.Bold, fontSize = 20.sp),
        titleLarge = titleLarge.copy(fontFamily = Cairo, fontWeight = FontWeight.Bold, fontSize = 17.sp),
        titleMedium = titleMedium.copy(fontFamily = Cairo, fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
        titleSmall = titleSmall.copy(fontFamily = Cairo, fontWeight = FontWeight.SemiBold, fontSize = 13.sp),
        bodyLarge = bodyLarge.copy(fontFamily = Cairo, fontSize = 14.sp),
        bodyMedium = bodyMedium.copy(fontFamily = Cairo, fontSize = 13.sp),
        bodySmall = bodySmall.copy(fontFamily = Cairo, fontSize = 12.sp, color = Brand.Muted),
        labelLarge = labelLarge.copy(fontFamily = Cairo, fontWeight = FontWeight.SemiBold, fontSize = 13.sp),
        labelMedium = labelMedium.copy(fontFamily = Cairo, fontSize = 12.sp),
        labelSmall = labelSmall.copy(fontFamily = Cairo, fontSize = 11.sp),
    )
}

val WordmarkStyle = TextStyle(
    fontFamily = Cairo,
    fontWeight = FontWeight.Bold,
    fontSize = 15.sp,
    letterSpacing = 4.sp,
)

private val ShopShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(10.dp),
    large = RoundedCornerShape(12.dp),
    extraLarge = RoundedCornerShape(16.dp),
)

private val Colors = lightColorScheme(
    primary = Brand.Ink,
    onPrimary = Color.White,
    primaryContainer = Brand.RoseSoft,
    onPrimaryContainer = Brand.RoseDark,
    secondary = Brand.Ink,
    onSecondary = Color.White,
    secondaryContainer = Brand.RoseSoft,
    onSecondaryContainer = Brand.RoseDark,
    tertiary = Brand.Ink,
    background = Brand.Canvas,
    onBackground = Brand.Ink,
    surface = Color.White,
    onSurface = Brand.Ink,
    surfaceVariant = Color(0xFFF7F7F7),
    onSurfaceVariant = Brand.Muted,
    outline = Brand.Line,
    outlineVariant = Brand.Line,
    error = Color(0xFFC0392B),
)

/** Light only — the storefront look is white, so the system dark theme is ignored. */
@Composable
fun ShopTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = Colors,
        typography = ShopTypography,
        shapes = ShopShapes,
        content = content,
    )
}
