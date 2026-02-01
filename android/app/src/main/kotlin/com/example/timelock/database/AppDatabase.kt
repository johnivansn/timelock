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
            "CREATE TABLE IF NOT EXISTS activity_logs (" +
                    "id TEXT PRIMARY KEY NOT NULL, " +
                    "timestamp INTEGER NOT NULL, " +
                    "eventType TEXT NOT NULL, " +
                    "packageName TEXT, " +
                    "appName TEXT, " +
                    "details TEXT NOT NULL, " +
                    "metadata TEXT)"
    )
    database.execSQL(
            "CREATE INDEX IF NOT EXISTS index_activity_logs_timestamp ON activity_logs(timestamp)"
    )
    database.execSQL(
            "CREATE INDEX IF NOT EXISTS index_activity_logs_packageName ON activity_logs(packageName)"
    )
    database.execSQL(
            "CREATE INDEX IF NOT EXISTS index_activity_logs_eventType ON activity_logs(eventType)"
    )
  }
}

class Migration3To4 : Migration(3, 4) {
  override fun migrate(database: SupportSQLiteDatabase) {
    database.execSQL(
            "CREATE TABLE IF NOT EXISTS admin_settings_new (" +
                    "id INTEGER PRIMARY KEY NOT NULL, " +
                    "isEnabled INTEGER NOT NULL DEFAULT 0, " +
                    "pinHash TEXT NOT NULL DEFAULT '', " +
                    "failedAttempts INTEGER NOT NULL DEFAULT 0, " +
                    "lockedUntil INTEGER NOT NULL DEFAULT 0, " +
                    "recoveryMode INTEGER NOT NULL DEFAULT 0, " +
                    "recoveryStartTime INTEGER NOT NULL DEFAULT 0, " +
                    "securityQuestion TEXT, " +
                    "securityAnswerHash TEXT, " +
                    "recoveryEmail TEXT)"
    )
    database.execSQL(
            "INSERT INTO admin_settings_new (id, isEnabled, pinHash, failedAttempts, lockedUntil) " +
                    "SELECT id, isEnabled, pinHash, failedAttempts, lockedUntil FROM admin_settings"
    )
    database.execSQL("DROP TABLE admin_settings")
    database.execSQL("ALTER TABLE admin_settings_new RENAME TO admin_settings")
  }
}

@Database(
        entities =
                [
                        AppRestriction::class,
                        DailyUsage::class,
                        AdminSettings::class,
                        ActivityLog::class],
        version = 4,
        exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
  abstract fun appRestrictionDao(): AppRestrictionDao
  abstract fun dailyUsageDao(): DailyUsageDao
  abstract fun adminSettingsDao(): AdminSettingsDao
  abstract fun activityLogDao(): ActivityLogDao

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
                                .addMigrations(Migration1To2(), Migration2To3(), Migration3To4())
                                .build()
                INSTANCE = instance
                instance
              }
    }
  }
}
