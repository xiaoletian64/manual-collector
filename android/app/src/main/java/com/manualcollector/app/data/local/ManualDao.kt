package com.manualcollector.app.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.manualcollector.app.data.model.Manual
import com.manualcollector.app.data.model.OcrPage
import kotlinx.coroutines.flow.Flow

@Dao
interface ManualDao {

    @Query("SELECT * FROM manuals ORDER BY updatedAt DESC")
    fun getAllManuals(): Flow<List<Manual>>

    @Query("SELECT * FROM manuals WHERE id = :id")
    suspend fun getManual(id: Long): Manual?

    @Query("SELECT * FROM manuals WHERE title LIKE '%' || :query || '%'")
    suspend fun searchManuals(query: String): List<Manual>

    @Query("SELECT * FROM manuals WHERE isFavorite = 1 ORDER BY updatedAt DESC")
    fun getFavorites(): Flow<List<Manual>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertManual(manual: Manual): Long

    @Update
    suspend fun updateManual(manual: Manual)

    @Delete
    suspend fun deleteManual(manual: Manual)

    @Query("DELETE FROM manuals WHERE id = :id")
    suspend fun deleteManualById(id: Long)

    @Query("UPDATE manuals SET favorite = :value WHERE id = :id")
    suspend fun setFavorite(id: Long, value: Boolean)

    @Query("UPDATE manuals SET completeness_score = :score WHERE id = :id")
    suspend fun updateCompletenessScore(id: Long, score: Float)

    @Query("UPDATE manuals SET cloud_sync_status = :status, cloud_file_id = :fileId WHERE id = :id")
    suspend fun updateCloudSync(id: Long, status: Int, fileId: String)
}

@Dao
interface OcrPageDao {

    @Query("SELECT * FROM ocr_pages WHERE manual_id = :manualId ORDER BY page_index ASC")
    fun getPagesByManual(manualId: Long): Flow<List<OcrPage>>

    @Query("SELECT * FROM ocr_pages WHERE manual_id = :manualId ORDER BY page_index ASC")
    suspend fun getPagesList(manualId: Long): List<OcrPage>

    @Query("SELECT * FROM ocr_pages WHERE id = :id")
    suspend fun getPage(id: Long): OcrPage?

    @Query("SELECT COUNT(*) FROM ocr_pages WHERE manual_id = :manualId")
    suspend fun countPages(manualId: Long): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPage(page: OcrPage): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(pages: List<OcrPage>): List<Long>

    @Update
    suspend fun updatePage(page: OcrPage)

    @Delete
    suspend fun deletePage(page: OcrPage)

    @Query("DELETE FROM ocr_pages WHERE manual_id = :manualId")
    suspend fun deleteAllPagesForManual(manualId: Long)
}
