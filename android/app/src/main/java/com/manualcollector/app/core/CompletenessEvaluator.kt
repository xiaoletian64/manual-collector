package com.manualcollector.app.core

import com.manualcollector.app.data.model.CompletenessDimension
import com.manualcollector.app.data.model.CompletenessDimensionType
import com.manualcollector.app.data.model.CompletenessReport

class CompletenessEvaluator {

    private val keywordPatterns = mapOf(
        CompletenessDimensionType.COVER to listOf(
            "型号", "产品名称", "品牌", "规格", "产品型号",
            "model", "product", "brand", "specification",
        ),
        CompletenessDimensionType.TABLE_OF_CONTENTS to listOf(
            "目录", "目錄", "contents", "index", "章节",
        ),
        CompletenessDimensionType.INSTALLATION to listOf(
            "安装", "安装说明", "安装步骤", "组装", "装配",
            "installation", "setup", "assembly", "mounting",
            "连接", "接线", "布线", "电源",
        ),
        CompletenessDimensionType.OPERATION to listOf(
            "操作", "使用", "操作说明", "使用方法", "功能",
            "operation", "usage", "how to use", "controls",
            "设置", "调节", "调整", "模式",
        ),
        CompletenessDimensionType.SAFETY to listOf(
            "安全", "警告", "注意", "维护", "保养",
            "safety", "warning", "caution", "maintenance",
            "清洁", "故障排除", "存储", "保修",
        ),
    )

    fun evaluate(text: String): CompletenessReport {
        val dimensions = CompletenessDimensionType.entries.map { dim ->
            val keywords = keywordPatterns[dim] ?: emptyList()
            val found = keywords.count { keyword ->
                text.contains(keyword, ignoreCase = true)
            }
            val maxPossible = keywords.size.coerceAtMost(5)
            val rawScore = (found.toFloat() / maxPossible).coerceIn(0f, 1f)
            val boost = calculatePageBoost(text, dim)
            val finalScore = (rawScore * 0.7f + boost * 0.3f).coerceIn(0f, 1f)

            CompletenessDimension(
                name = dim.displayName,
                score = finalScore,
                weight = dim.defaultWeight,
                details = "匹配关键词 ${found}/${maxPossible}",
            )
        }

        val overallScore = dimensions.sumOf {
            it.score * it.weight
        }.toFloat().coerceIn(0f, 1f)

        return CompletenessReport(
            overallScore = overallScore,
            dimensions = dimensions,
            isComplete = overallScore >= 0.8f,
        )
    }

    private fun calculatePageBoost(text: String, type: CompletenessDimensionType): Float {
        val lines = text.lines().size
        return when (type) {
            CompletenessDimensionType.COVER ->
                if (text.contains("第1页") || text.contains("Page 1")) 0.5f else 0.2f
            CompletenessDimensionType.TABLE_OF_CONTENTS ->
                if (lines > 3) 0.6f else 0.3f
            CompletenessDimensionType.INSTALLATION,
            CompletenessDimensionType.OPERATION -> {
                val stepPattern = Regex("\\d+[.、． ]")
                val steps = stepPattern.findAll(text).count()
                (steps.toFloat() / 10f).coerceIn(0f, 1f)
            }
            CompletenessDimensionType.SAFETY ->
                if (text.contains("⚠") || text.contains("!")) 0.7f else 0.4f
        }
    }

    fun evaluateAllPages(pages: List<String>): CompletenessReport {
        if (pages.isEmpty()) return CompletenessReport(isComplete = false)
        val combined = pages.joinToString("\n---\n")
        return evaluate(combined)
    }
}
