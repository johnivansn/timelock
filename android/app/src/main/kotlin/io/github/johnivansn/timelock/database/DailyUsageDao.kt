package io.github.johnivansn.timelock.database

import androidx.room.*

@Dao
interface DailyUsageDao {
  @Query("SELECT * FROM daily_usage WHERE packageName = :packageName AND date = :date LIMIT 1")
  suspend fun getUsage(packageName: String, date: String): DailyUsage?

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(usage: DailyUsage)

  @Update suspend fun update(usage: DailyUsage)

  @Delete suspend fun delete(usage: DailyUsage)

  @Query("UPDATE daily_usage SET usedMinutes = 0, isBlocked = 0 WHERE date = :date")
  suspend fun resetUsageForDate(date: String)

  @Query("DELETE FROM daily_usage WHERE date < :date") suspend fun deleteOldUsage(date: String)

  @Query("SELECT * FROM daily_usage") suspend fun getAllUsage(): List<DailyUsage>

  @Query("SELECT * FROM daily_usage WHERE packageName = :packageName AND date >= :fromDate")
  suspend fun getUsageSince(packageName: String, fromDate: String): List<DailyUsage>

  @Query(
          "UPDATE daily_usage SET isBlocked = :blocked, lastUpdated = :updatedAt " +
                  "WHERE packageName = :packageName AND date = :date"
  )
  suspend fun setBlockedForPackageDate(
          packageName: String,
          date: String,
          blocked: Boolean,
          updatedAt: Long
  )
}

