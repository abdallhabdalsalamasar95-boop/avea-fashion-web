package ly.carmenkarla.admin.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Black = Color(0xFF111111)
private val White = Color(0xFFFFFFFF)
private val Gray = Color(0xFFF2F2F2)

private val LightColors = lightColorScheme(
    primary = Black,
    onPrimary = White,
    primaryContainer = Gray,
    onPrimaryContainer = Black,
    secondary = Black,
    onSecondary = White,
    background = White,
    onBackground = Black,
    surface = White,
    onSurface = Black,
    surfaceVariant = Gray,
    error = Color(0xFFB3261E),
)

private val DarkColors = darkColorScheme(
    primary = White,
    onPrimary = Black,
    primaryContainer = Color(0xFF333333),
    onPrimaryContainer = White,
    secondary = White,
    onSecondary = Black,
    secondaryContainer = Color(0xFF333333),
    onSecondaryContainer = White,
    background = Black,
    surface = Color(0xFF1D1D1D),
    surfaceVariant = Color(0xFF333333),
    onSurfaceVariant = Color(0xFFDDDDDD),
)

@Composable
fun AdminTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = Typography(),
        content = content,
    )
}
