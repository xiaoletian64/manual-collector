package com.manualcollector.app.data.model

data class ChatMessage(
    val id: Long = System.nanoTime(),
    val role: Role = Role.USER,
    val content: String = "",
    val timestamp: Long = System.currentTimeMillis(),
    val references: List<Reference> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
) {
    enum class Role { USER, ASSISTANT, SYSTEM }
}

data class Reference(
    val manualId: Long,
    val manualTitle: String,
    val pageIndex: Int,
    val snippet: String,
    val relevance: Float = 0f,
)
