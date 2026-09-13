package ly.carmenkarla.shop.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import ly.carmenkarla.shop.R
import ly.carmenkarla.shop.ui.theme.Brand
import ly.carmenkarla.shop.ui.theme.WordmarkStyle

/** Brand intro shown once per cold start while the catalog loads. */
@Composable
fun WelcomeScreen(onDone: () -> Unit) {
    val mark = remember { Animatable(0f) }
    val ring = remember { Animatable(0f) }
    val wordmark = remember { Animatable(0f) }
    val tagline = remember { Animatable(0f) }
    val progress = remember { Animatable(0f) }

    LaunchedEffect(Unit) { mark.animateTo(1f, tween(620, easing = FastOutSlowInEasing)) }
    LaunchedEffect(Unit) {
        delay(120)
        ring.animateTo(1f, tween(900, easing = FastOutSlowInEasing))
    }
    LaunchedEffect(Unit) {
        delay(420)
        wordmark.animateTo(1f, tween(520))
    }
    LaunchedEffect(Unit) {
        delay(680)
        tagline.animateTo(1f, tween(520))
    }
    LaunchedEffect(Unit) {
        progress.animateTo(1f, tween(2100, easing = LinearEasing))
        onDone()
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(
                // Warm off-white centre fading to plain white keeps it soft on the eye.
                Brush.radialGradient(listOf(Color(0xFFFFFBF7), Color(0xFFFFFFFF))),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Image(
                painter = painterResource(R.drawable.brand_mark),
                contentDescription = "Carmen Karla",
                modifier = Modifier
                    .fillMaxWidth(0.78f)
                    .scale(0.9f + mark.value * 0.1f)
                    .alpha(mark.value),
            )

            Spacer(Modifier.height(18.dp))

            Row(
                Modifier.alpha(tagline.value),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Rule(46.dp)
                Text(
                    "أناقة تُصنع لكِ",
                    Modifier.padding(horizontal = 14.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = Brand.RoseDark,
                )
                Rule(46.dp)
            }
        }

        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 48.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier
                    .width(96.dp)
                    .height(1.5.dp)
                    .clip(CircleShape)
                    .background(Brand.Line),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(progress.value)
                        .fillMaxSize()
                        .clip(CircleShape)
                        .background(Brush.horizontalGradient(listOf(Brand.Gold, Brand.RoseDark))),
                )
            }
            Spacer(Modifier.height(16.dp))
            Text(
                "متجر الأناقة النسائية · ليبيا",
                style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.sp),
                color = Brand.Muted,
            )
        }
    }
}

@Composable
private fun Rule(width: Dp) {
    Box(
        Modifier
            .width(width)
            .height(1.dp)
            .background(
                Brush.horizontalGradient(
                    listOf(Color.Transparent, Brand.Gold.copy(alpha = 0.6f), Color.Transparent),
                ),
            ),
    )
}
