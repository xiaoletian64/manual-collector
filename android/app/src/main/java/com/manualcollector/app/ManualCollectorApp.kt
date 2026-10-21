package com.manualcollector.app

import android.app.Application
import androidx.room.Room
import com.manualcollector.app.core.EmbeddingService
import com.manualcollector.app.data.local.AppDatabase

class ManualCollectorApp : Application() {

    lateinit var database: AppDatabase
        private set

    lateinit var embeddingService: EmbeddingService
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this

        database = Room.databaseBuilder(
            applicationContext,
            AppDatabase::class.java,
            "manual_collector.db",
        )
            .fallbackToDestructiveMigration()
            .build()

        embeddingService = EmbeddingService(applicationContext)
    }

    fun getDatabase(): AppDatabase = database
    fun getEmbeddingService(): EmbeddingService = embeddingService

    companion object {
        lateinit var instance: ManualCollectorApp
            private set
    }
}
