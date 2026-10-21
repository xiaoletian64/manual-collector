package com.manualcollector.app.data.model

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "ocr_pages",
    indices = [Index(value = ["manual_id", "page_index"], unique = true)],
    foreignKeys = [
        ForeignKey(
            entity = Manual::class,
            parentColumns = ["id"],
            childColumns = ["manual_id"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
)
data class OcrPage(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    @ColumnInfo(name = "manual_id") val manualId: Long,
    @ColumnInfo(name = "page_index") val pageIndex: Int = 0,
    val imageUri: String = "",
    val text: String = "",
    @ColumnInfo(name = "image_width") val width: Int = 0,
    @ColumnInfo(name = "image_height") val height: Int = 0,
    val blockCount: Int = 0,
    val confidence: Float = 0f,
    @ColumnInfo(name = "processed_at") val processedAt: Long = System.currentTimeMillis(),
) {

    val blocks: List<TextBlock>
        get() = parsedBlocks()

    private fun parsedBlocks(): List<TextBlock> {
        val json = text
        val result = mutableListOf<TextBlock>()
        if (json.isEmpty()) return result
        try {
            val lines = json.split("\n")
            for ((index, line) in lines.withIndex()) {
                if (line.isNotBlank())
                    result.add(TextBlock(text = line, index = index, confidence = confidence))
            }
        } catch (_: Throwable) {
        }
        return result
    }
}

data class TextBlock(
    val text: String,
    val index: Int,
    val confidence: Float,
    val boundingBox: BoundingBox? = null,
)

data class BoundingBox(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
)
