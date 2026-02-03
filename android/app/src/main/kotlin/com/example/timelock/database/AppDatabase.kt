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

class Migration2To3 : Migration(2, 3) {
  override fun migrate(database: SupportSQLiteDatabase) {
    database.execSQL(
            "CREATE TABLE IF NOT EXISTS wifi_history (" +
                    "ssid TEXT PRIMARY KEY NOT NULL, " +
                    "firstSeen INTEGER NOT NULL, " +
                    "lastSeen INTEGER NOT NULL)"
    )
  }
}

class Migration3To4 : Migration(3, 4) {
  override fun migrate(database: SupportSQLiteDatabase) {
    database.execSQL(
            "CREATE TABLE IF NOT EXISTS app_schedules (" +
                    "id TEXT PRIMARY KEY NOT NULL, " +
                    "packageName TEXT NOT NULL, " +
                    "startHour INTEGER NOT NULL, " +
                    "startMinute INTEGER NOT NULL, " +
                    "endHour INTEGER NOT NULL, " +
                    "endMinute INTEGER NOT NULL, " +
                    "daysOfWeek TEXT NOT NULL, " +
                    "isEnabled INTEGER NOT NULL, " +
                    "createdAt INTEGER NOT NULL)"
    )
  }
}

class Migration4To5 : Migration(4, 5) {
  override fun migrate(database: SupportSQLiteDatabase) {
    try {
      database.execSQL(
              "CREATE TABLE IF NOT EXISTS app_schedules_new (" +
                      "id TEXT PRIMARY KEY NOT NULL, " +
                      "packageName TEXT NOT NULL, " +
                      "startHour INTEGER NOT NULL, " +
                      "startMinute INTEGER NOT NULL, " +
                      "endHour INTEGER NOT NULL, " +
                      "endMinute INTEGER NOT NULL, " +
                      "daysOfWeek INTEGER NOT NULL DEFAULT 0, " +
                      "isEnabled INTEGER NOT NULL DEFAULT 1, " +
                      "createdAt INTEGER NOT NULL)"
      )

      database.execSQL(
              "INSERT INTO app_schedules_new " +
                      "SELECT id, packageName, startHour, startMinute, endHour, endMinute, 0, isEnabled, createdAt " +
                      "FROM app_schedules"
      )

      database.execSQL("DROP TABLE IF EXISTS app_schedules")
      database.execSQL("ALTER TABLE app_schedules_new RENAME TO app_schedules")
    } catch (e: Exception) {
      android.util.Log.e("Migration4To5", "Error migrating", e)
      throw e
    }
  }
}

@Database(
        entities =
                [
                        AppRestriction::class,
                        DailyUsage::class,
                        AdminSettings::class,
                        WifiHistory::class,
                        AppSchedule::class],
        version = 5,
        exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
  abstract fun appRestrictionDao(): AppRestrictionDao
  abstract fun dailyUsageDao(): DailyUsageDao
  abstract fun adminSettingsDao(): AdminSettingsDao
  abstract fun wifiHistoryDao(): WifiHistoryDao
  abstract fun appScheduleDao(): AppScheduleDao

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
                                .addMigrations(
                                        Migration1To2(),
                                        Migration2To3(),
                                        Migration3To4(),
                                        Migration4To5()
                                )
                                .build()
                INSTANCE = instance
                instance
              }
    }
  }
}
