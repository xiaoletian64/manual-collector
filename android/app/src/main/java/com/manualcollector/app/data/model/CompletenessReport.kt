package com.manualcollector.app.data.model

data class CompletenessReport(
    val manualId: Long = 0,
    val title: String = "",
    val dimensions: List<CompletenessDimension> = emptyList(),
    val overallScore: Float = 0f,
    val isComplete: Boolean = false,
)

data class CompletenessDimension(
    val name: String,
    val score: Float,
    val weight: Float = 1f,
    val details: String = "",
)

enum class CompletenessDimensionType(
    val displayName: String,
    val defaultWeight: Float,
) {
    COVER("封面/标识信息", 0.20f),
    TABLE_OF_CONTENTS("目录完整性", 0.15f),
    INSTALLATION("安装说明", 0.25f),
    OPERATION("操作指南", 0.25f),
    SAFETY("安全与维护", 0.15f),
}
