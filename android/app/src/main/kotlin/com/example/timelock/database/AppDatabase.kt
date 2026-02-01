package com.example.timelock.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

class Migration1To2 : Migration(1, 2) {
  override fun migrate(database: SupportSQLiteDatabase) {
    database.execSQL(
            "CREATE TABLE IF NOT EXISTS admin_settings (" +
                    "id INTEGER PRIMARY KEY NOT NULL, " +
                    "isEnabled INTEGER NOT NULL DEFAULT 0, " +
                    "pinHash TEXT NOT NULL DEFAULT '', " +
                    "failedAttempts INTEGER NOT NULL DEFAULT 0, " +
                    "lockedUntil INTEGER NOT NULL DEFAULT 0)"
    )
  }
}

@Database(
        entities = [AppRestriction::class, DailyUsage::class, AdminSettings::class],
        version = 2,
        exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
  abstract fun appRestrictionDao(): AppRestrictionDao
  abstract fun dailyUsageDao(): DailyUsageDao
  abstract fun adminSettingsDao(): AdminSettingsDao

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
                                .addMigrations(Migration1To2())
                                .build()
                INSTANCE = instance
                instance
              }
    }
  }
}
