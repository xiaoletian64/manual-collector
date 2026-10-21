package com.manualcollector.app.data.model

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "manuals", indices = [Index(value = ["title"], unique = false)])
data class Manual(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String = "",
    val subtitle: String = "",
    val brand: String = "",
    val productCode: String = "",
    val category: String = "",
    val language: String = "zh-CN",
    val coverPath: String = "",
    val totalPages: Int = 0,
    val scannedPages: Int = 0,
    @ColumnInfo(name = "completeness_score") val completenessScore: Float = 0f,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val cloudSyncStatus: Int = 0,
    val cloudFileId: String = "",
    val isFavorite: Boolean = false,
    val tags: String = "",
)
