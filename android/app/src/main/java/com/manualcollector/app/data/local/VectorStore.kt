package com.manualcollector.app.data.local

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class VectorSearchResult(
    val rowId: Long,
    val manualId: Long,
    val pageIndex: Int,
    val text: String,
    val distance: Float,
)

class VectorStore(private val context: Context) {

    private var initialized = false

    suspend fun initialize() = withContext(Dispatchers.IO) {
        if (initialized) return@withContext
        try {
            System.loadLibrary("sqlite-vec")
            initialized = true
        } catch (e: UnsatisfiedLinkError) {
            throw RuntimeException("sqlite-vec native library not found", e)
        }
    }

    suspend fun buildTableIfNeeded(dbPath: String) = withContext(Dispatchers.IO) {
        ensureInitialized()
        val jdbc = "jdbc:sqlite:$dbPath"
        val conn = java.sql.DriverManager.getConnection(jdbc)
        conn.use { c ->
            c.createStatement().execute(
                """
                CREATE VIRTUAL TABLE IF NOT EXISTS vector_store USING vec0(
                    embedding FLOAT[384] distance_metric=cosine,
                    +page_id INTEGER,
                    +manual_id INTEGER,
                    +page_index INTEGER,
                    +text TEXT
                )
                """.trimIndent(),
            )
        }
    }

    suspend fun upsert(
        dbPath: String,
        pageId: Long,
        manualId: Long,
        pageIndex: Int,
        text: String,
        embedding: FloatArray,
    ) = withContext(Dispatchers.IO) {
        ensureInitialized()
        val jdbc = "jdbc:sqlite:$dbPath"
        val conn = java.sql.DriverManager.getConnection(jdbc)
        conn.use { c ->
            val ps = c.prepareStatement(
                "INSERT INTO vector_store(row_id, embedding, page_id, manual_id, page_index, text) VALUES (?, ?, ?, ?, ?, ?)",
            )
            ps.setLong(1, pageId)
            val blob = embedding.joinToString(",")
            ps.setString(2, "[$blob]")
            ps.setLong(3, pageId)
            ps.setLong(4, manualId)
            ps.setInt(5, pageIndex)
            ps.setString(6, text)
            ps.executeUpdate()
        }
    }

    suspend fun search(
        dbPath: String,
        queryEmbedding: FloatArray,
        limit: Int = 10,
    ): List<VectorSearchResult> = withContext(Dispatchers.IO) {
        ensureInitialized()
        val jdbc = "jdbc:sqlite:$dbPath"
        val conn = java.sql.DriverManager.getConnection(jdbc)
        conn.use { c ->
            val ps = c.prepareStatement(
                """
                SELECT row_id, manual_id, page_index, text, distance
                FROM vector_store
                WHERE embedding MATCH ?
                ORDER BY distance
                LIMIT ?
                """.trimIndent(),
            )
            val blob = queryEmbedding.joinToString(",")
            ps.setString(1, "[$blob]")
            ps.setInt(2, limit)
            val rs = ps.executeQuery()
            val results = mutableListOf<VectorSearchResult>()
            while (rs.next()) {
                results.add(
                    VectorSearchResult(
                        rowId = rs.getLong("row_id"),
                        manualId = rs.getLong("manual_id"),
                        pageIndex = rs.getInt("page_index"),
                        text = rs.getString("text"),
                        distance = rs.getFloat("distance"),
                    ),
                )
            }
            results
        }
    }

    private fun ensureInitialized() {
        if (!initialized) {
            try {
                System.loadLibrary("sqlite-vec")
                initialized = true
            } catch (e: UnsatisfiedLinkError) {
                throw RuntimeException("sqlite-vec native library not found", e)
            }
        }
    }
}
