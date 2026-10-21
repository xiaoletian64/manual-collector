package com.manualcollector.app.core

import android.util.Log
import com.manualcollector.app.data.model.OcrPage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.TimeUnit

data class RAGResult(
    val answer: String,
    val references: List<ChatReference> = emptyList()
)

data class ChatReference(
    val page: Int,
    val text: String
)

data class Chunk(
    val id: UUID,
    val manualId: UUID,
    val productName: String,
    val page: Int,
    val text: String
)

class RAGService(
    private val apiKey: String,
    private val baseURL: String = "https://api.deepseek.com/v1",
    private val model: String = "deepseek-chat"
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()
    
    private val chunks = mutableListOf<Chunk>()
    
    fun indexManual(manualId: UUID, productName: String, pages: List<OcrPage>) {
        for (page in pages) {
            val blocks = chunkText(page.text, maxLength = 256)
            for (block in blocks) {
                chunks.add(Chunk(
                    id = UUID.randomUUID(),
                    manualId = manualId,
                    productName = productName,
                    page = page.pageNumber,
                    text = block
                ))
            }
        }
    }
    
    suspend fun query(question: String, manualId: UUID, topK: Int = 5): RAGResult = withContext(Dispatchers.IO) {
        val relevant = retrieve(question, manualId, topK)
        
        if (relevant.isEmpty()) {
            return@withContext RAGResult("未在说明书中找到相关内容。")
        }
        
        val context = relevant.joinToString("\n") { "[第${it.page}页] ${it.text}" }
        
        val prompt = """
你是一个说明书助手。只基于以下说明书内容回答用户问题。
如果信息不在原文中，请回答"未在说明书中找到"。
在回答末尾标注引用页码，如（第3页）。

说明书内容：
===
$context
===

用户问：$question

回答：
""".trimIndent()
        
        val answer = callLLM(prompt)
        val refs = relevant.map { ChatReference(page = it.page, text = it.text) }
        RAGResult(answer = answer, references = refs)
    }
    
    private fun retrieve(question: String, manualId: UUID, topK: Int): List<ChunkScore> {
        val queryWords = question.lowercase()
            .replace(Regex("[，。！？、；：\"'【】（）《》\\n]"), " ")
            .split(" ")
            .filter { it.isNotBlank() }
            .toSet()
        
        val manualChunks = chunks.filter { it.manualId == manualId }
        
        return manualChunks.map { chunk ->
            val chunkWords = chunk.text.lowercase()
                .replace(Regex("[，。！？、；：\"'【】（）《》\\n]"), " ")
                .split(" ")
                .filter { it.isNotBlank() }
                .toSet()
            
            val intersection = queryWords.intersect(chunkWords)
            val score = if (queryWords.isEmpty()) 0.0 else intersection.size.toDouble() / queryWords.size
            ChunkScore(chunk, score)
        }
        .filter { it.score > 0 }
        .sortedByDescending { it.score }
        .take(topK)
    }
    
    private fun callLLM(prompt: String): String {
        val url = "$baseURL/chat/completions"
        
        val messages = JSONArray().apply {
            put(JSONObject().apply {
                put("role", "system")
                put("content", "你是一个专业的说明书助手，基于提供的说明书内容回答用户问题，回复简洁准确，使用中文，标注引用页码。")
            })
            put(JSONObject().apply {
                put("role", "user")
                put("content", prompt)
            })
        }
        
        val bodyJson = JSONObject().apply {
            put("model", model)
            put("messages", messages)
            put("temperature", 0.3)
            put("max_tokens", 512)
        }
        
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $apiKey")
            .addHeader("Content-Type", "application/json")
            .post(bodyJson.toString().toRequestBody("application/json".toMediaType()))
            .build()
        
        try {
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: throw Exception("Empty response")
            val json = JSONObject(responseBody)
            val choices = json.getJSONArray("choices")
            val message = choices.getJSONObject(0).getJSONObject("message")
            return message.getString("content")
        } catch (e: Exception) {
            Log.e("RAGService", "LLM call failed", e)
            return "抱歉，暂时无法回答。"
        }
    }
    
    private fun chunkText(text: String, maxLength: Int): List<String> {
        val sentences = text.split(Regex("[。！？\\n]"))
        val result = mutableListOf<String>()
        var current = ""
        for (sentence in sentences) {
            val trimmed = sentence.trim()
            if (trimmed.isEmpty()) continue
            if (current.length + trimmed.length > maxLength) {
                if (current.isNotEmpty()) result.add(current)
                current = trimmed
            } else {
                current += if (current.isEmpty()) trimmed else "。$trimmed"
            }
        }
        if (current.isNotEmpty()) result.add(current)
        return result.ifEmpty { listOf(text) }
    }
    
    data class ChunkScore(val chunk: Chunk, val score: Double)
}
