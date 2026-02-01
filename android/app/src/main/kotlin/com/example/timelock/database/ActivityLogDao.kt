package com.example.timelock.database

import androidx.room.*

@Dao
interface ActivityLogDao {
  @Query("SELECT * FROM activity_logs ORDER BY timestamp DESC LIMIT :limit")
  suspend fun getRecent(limit: Int = 100): List<ActivityLog>

  @Query("SELECT * FROM activity_logs WHERE timestamp >= :startTime ORDER BY timestamp DESC")
  suspend fun getLogsSince(startTime: Long): List<ActivityLog>

  @Query(
          "SELECT * FROM activity_logs WHERE packageName = :packageName ORDER BY timestamp DESC LIMIT :limit"
  )
  suspend fun getLogsForApp(packageName: String, limit: Int = 50): List<ActivityLog>

  @Query(
          "SELECT * FROM activity_logs WHERE eventType = :eventType ORDER BY timestamp DESC LIMIT :limit"
  )
  suspend fun getLogsByType(eventType: String, limit: Int = 50): List<ActivityLog>

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(log: ActivityLog)

  @Query("DELETE FROM activity_logs WHERE timestamp < :cutoffTime")
  suspend fun deleteOldLogs(cutoffTime: Long)

  @Query("DELETE FROM activity_logs") suspend fun deleteAll()

  @Query("SELECT COUNT(*) FROM activity_logs") suspend fun getCount(): Int
}
