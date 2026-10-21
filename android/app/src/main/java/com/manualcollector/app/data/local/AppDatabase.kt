package com.manualcollector.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.manualcollector.app.data.model.Manual
import com.manualcollector.app.data.model.OcrPage

@Database(
    entities = [Manual::class, OcrPage::class],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {

    abstract fun manualDao(): ManualDao
    abstract fun ocrPageDao(): OcrPageDao
}
