package com.manualcollector.app.core

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

data class OcrResult(
    val text: String,
    val confidence: Float,
    val blockCount: Int,
    val blocks: List<OcrBlock> = emptyList(),
)

data class OcrBlock(
    val text: String,
    val confidence: Float,
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
)

class OCRService {

    private val recognizer by lazy {
        TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    }

    suspend fun recognize(bitmap: Bitmap): OcrResult = withContext(Dispatchers.Default) {
        val image = InputImage.fromBitmap(bitmap, 0)
        val visionText = recognizer.process(image).await()
        val sb = StringBuilder()
        val blocks = mutableListOf<OcrBlock>()
        var totalConf = 0f
        var blockCount = 0

        for (block in visionText.textBlocks) {
            val box = block.boundingBox ?: continue
            for (line in block.lines) {
                if (line.text.isBlank()) continue
                if (sb.isNotEmpty()) sb.append("\n")
                sb.append(line.text)
                totalConf += line.confidence
                blockCount++
                blocks.add(
                    OcrBlock(
                        text = line.text,
                        confidence = line.confidence,
                        left = box.left,
                        top = box.top,
                        right = box.right,
                        bottom = box.bottom,
                    ),
                )
            }
        }

        OcrResult(
            text = sb.toString(),
            confidence = if (blockCount > 0) totalConf / blockCount else 0f,
            blockCount = blockCount,
            blocks = blocks,
        )
    }

    fun release() {
        recognizer.close()
    }
}
