package com.manualcollector.app.core

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class EmbeddingService(
    private val apiKey: String,
    private val baseURL: String = "https://api.deepseek.com/v1"
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()
    
    suspend fun embed(text: String): List<Float> {
        val url = "$baseURL/embeddings"
        
        val bodyJson = JSONObject().apply {
            put("model", "text-embedding-v2")
            put("input", text)
        }
        
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $apiKey")
            .addHeader("Content-Type", "application/json")
            .post(bodyJson.toString().toRequestBody("application/json".toMediaType()))
            .build()
        
        val response = client.newCall(request).execute()
        val responseBody = response.body?.string() ?: throw Exception("Empty response")
        val json = JSONObject(responseBody)
        val dataArr = json.getJSONArray("data")
        val embeddingArr = dataArr.getJSONObject(0).getJSONArray("embedding")
        
        return (0 until embeddingArr.length()).map { embeddingArr.getDouble(it).toFloat() }
    }
    
    companion object {
        fun cosineSimilarity(a: List<Float>, b: List<Float>): Float {
            if (a.size != b.size) return 0f
            var dotProduct = 0f
            var normA = 0f
            var normB = 0f
            for (i in a.indices) {
                dotProduct += a[i] * b[i]
                normA += a[i] * a[i]
                normB += b[i] * b[i]
            }
            val norm = kotlin.math.sqrt(normA) * kotlin.math.sqrt(normB)
            return if (norm > 0) dotProduct / norm else 0f
        }
    }
}
