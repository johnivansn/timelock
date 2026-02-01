package com.example.timelock.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

@Database(entities = [AppRestriction::class, DailyUsage::class], version = 1)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
  abstract fun appRestrictionDao(): AppRestrictionDao
  abstract fun dailyUsageDao(): DailyUsageDao

  companion object {
    @Volatile private var INSTANCE: AppDatabase? = null

    fun getDatabase(context: Context): AppDatabase {
      return INSTANCE
              ?: synchronized(this) {
                val instance =
                        Room.databaseBuilder(
                                        context.applicationContext,
                                        AppDatabase::class.java,
                                        "app_time_control_db"
                                )
                                .build()
                INSTANCE = instance
                instance
              }
    }
  }
}
