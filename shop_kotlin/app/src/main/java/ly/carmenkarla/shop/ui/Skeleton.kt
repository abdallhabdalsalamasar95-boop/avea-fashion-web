package ly.carmenkarla.shop.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/** Sweeping highlight that makes loading feel faster than a spinner. */
@Composable
fun shimmerBrush(): Brush {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val offset by transition.animateFloat(
        initialValue = -600f,
        targetValue = 900f,
        animationSpec = infiniteRepeatable(tween(1300), RepeatMode.Restart),
        label = "shimmerOffset",
    )
    val base = Color(0xFFEDEDED)
    val highlight = Color(0xFFF9F9F9)
    return Brush.linearGradient(
        colors = listOf(base, highlight, base),
        start = androidx.compose.ui.geometry.Offset(offset, 0f),
        end = androidx.compose.ui.geometry.Offset(offset + 300f, 300f),
    )
}

@Composable
fun ShimmerBox(modifier: Modifier, corner: Int = 8) {
    Spacer(modifier.clip(RoundedCornerShape(corner.dp)).background(shimmerBrush()))
}

/** Placeholder that mirrors the catalog grid so the layout does not jump when data lands. */
@Composable
fun CatalogSkeleton(modifier: Modifier = Modifier) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        userScrollEnabled = false,
    ) {
        item(span = { GridItemSpan(2) }) {
            ShimmerBox(
                Modifier
                    .fillMaxWidth()
                    .height(48.dp),
            )
        }
        item(span = { GridItemSpan(2) }) {
            ShimmerBox(
                Modifier
                    .fillMaxWidth()
                    .aspectRatio(1.9f),
                corner = 0,
            )
        }
        item(span = { GridItemSpan(2) }) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                repeat(5) {
                    ShimmerBox(
                        Modifier
                            .height(52.dp)
                            .aspectRatio(1f),
                        corner = 26,
                    )
                }
            }
        }
        items(6) {
            Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                ShimmerBox(
                    Modifier
                        .fillMaxWidth()
                        .aspectRatio(0.78f),
                    corner = 10,
                )
                ShimmerBox(
                    Modifier
                        .fillMaxWidth(0.85f)
                        .height(12.dp),
                    corner = 4,
                )
                ShimmerBox(
                    Modifier
                        .fillMaxWidth(0.45f)
                        .height(12.dp),
                    corner = 4,
                )
            }
        }
    }
}
