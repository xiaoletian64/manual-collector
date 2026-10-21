package com.manualcollector.app.ui.screens

import androidx.compose.animation.animateColorAsState
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.manualcollector.app.core.CompletenessEvaluator
import com.manualcollector.app.data.model.CompletenessDimension
import com.manualcollector.app.data.model.CompletenessReport

@Composable
fun ScanConfirmScreen(
    pageCount: Int,
    onRetake: () -> Unit,
    onSave: () -> Unit,
) {
    val evaluator = remember { CompletenessEvaluator() }
    var report by remember { mutableStateOf<CompletenessReport?>(null) }
    var isProcessing by remember { mutableStateOf(true) }
    var manualName by remember { mutableStateOf("") }
    var manualBrand by remember { mutableStateOf("") }

    val scrollState = rememberScrollState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(16.dp),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Text(
                text = "完整性评估",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )

            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "共扫描 $pageCount 页",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Manual info card
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("产品名称", style = MaterialTheme.typography.labelLarge)
                    Text(
                        text = manualName.ifEmpty { "待识别" },
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("品牌", style = MaterialTheme.typography.labelLarge)
                    Text(
                        text = manualBrand.ifEmpty { "待识别" },
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Overall score
            val overallScore = report?.overallScore ?: 0f
            val scoreColor by animateColorAsState(
                targetValue = when {
                    overallScore >= 0.8f -> Color(0xFF4CAF50)
                    overallScore >= 0.5f -> Color(0xFFFFC107)
                    else -> Color(0xFFF44336)
                },
                label = "scoreColor",
            )

            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = scoreColor.copy(alpha = 0.1f),
                ),
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "综合评分",
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "${(overallScore * 100).toInt()}%",
                        style = MaterialTheme.typography.displayLarge,
                        color = scoreColor,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Dimension scores
            Text(
                text = "评分维度",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.height(8.dp))

            val dims = report?.dimensions ?: CompletenessDimensionType.entries.map {
                CompletenessDimension(name = it.displayName, score = 0f, weight = it.defaultWeight)
            }

            dims.forEach { dim ->
                DimensionRow(dim)
                Spacer(modifier = Modifier.height(8.dp))
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                FilledTonalButton(
                    onClick = onRetake,
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Filled.PhotoCamera, "补拍", modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("补拍")
                }
                Button(
                    onClick = onSave,
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Filled.CheckCircle, "保存", modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("保存")
                }
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

@Composable
private fun DimensionRow(dim: CompletenessDimension) {
    val scoreColor by animateColorAsState(
        targetValue = when {
            dim.score >= 0.8f -> Color(0xFF4CAF50)
            dim.score >= 0.5f -> Color(0xFFFFC107)
            else -> Color(0xFFF44336)
        },
        label = "dimColor",
    )

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.small,
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = dim.name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                )
                Spacer(modifier = Modifier.height(4.dp))
                LinearProgressIndicator(
                    progress = dim.score,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(MaterialTheme.shapes.small),
                    color = scoreColor,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant,
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "${(dim.score * 100).toInt()}%",
                style = MaterialTheme.typography.titleMedium,
                color = scoreColor,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

private enum class CompletenessDimensionType(val displayName: String, val defaultWeight: Float) {
    COVER("封面/标识信息", 0.20f),
    TABLE_OF_CONTENTS("目录完整性", 0.15f),
    INSTALLATION("安装说明", 0.25f),
    OPERATION("操作指南", 0.25f),
    SAFETY("安全与维护", 0.15f),
}
