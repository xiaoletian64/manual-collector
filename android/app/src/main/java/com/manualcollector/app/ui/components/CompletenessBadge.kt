package com.manualcollector.app.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

@Composable
fun CompletenessBadge(
    score: Float,
    modifier: Modifier = Modifier,
    size: Int = 36,
    strokeWidth: Float = 3f,
) {
    var animatedTarget by remember { mutableStateOf(0f) }
    LaunchedEffect(score) { animatedTarget = score }

    val animatedScore by animateFloatAsState(
        targetValue = animatedTarget,
        animationSpec = tween(600),
        label = "score",
    )

    val color = when {
        score >= 0.8f -> Color(0xFF4CAF50)
        score >= 0.5f -> Color(0xFFFFC107)
        else -> Color(0xFFF44336)
    }

    Box(
        modifier = modifier.size(size.dp),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(size.dp)) {
            val stroke = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            val arcSize = Size(size.toFloat() - strokeWidth, size.toFloat() - strokeWidth)
            val topLeft = Offset(strokeWidth / 2, strokeWidth / 2)

            drawArc(
                color = Color.Black.copy(alpha = 0.12f),
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = stroke,
            )
            drawArc(
                color = color,
                startAngle = -90f,
                sweepAngle = 360f * animatedScore,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = stroke,
            )
        }
        Text(
            text = "${(animatedScore * 100).toInt()}%",
            style = MaterialTheme.typography.labelSmall,
            color = color,
        )
    }
}
