package com.example.timelock.database

import androidx.room.*

@Dao
interface TemporaryExceptionDao {
  @Query("SELECT * FROM temporary_exceptions WHERE packageName = :packageName")
  suspend fun getByPackage(packageName: String): List<TemporaryException>
  @Query(
          "SELECT * FROM temporary_exceptions WHERE packageName = :packageName ORDER BY startTime DESC LIMIT 1"
  )
  suspend fun getActiveByPackage(packageName: String): TemporaryException?
  @Query("SELECT * FROM temporary_exceptions") suspend fun getAll(): List<TemporaryException>
  @Query(
          "SELECT COUNT(*) FROM temporary_exceptions WHERE packageName = :packageName AND DATE(createdAt / 1000, 'unixepoch') = DATE('now')"
  )
  suspend fun countTodayByPackage(packageName: String): Int
  @Query(
          "SELECT SUM(durationMinutes) FROM temporary_exceptions WHERE DATE(createdAt / 1000, 'unixepoch') = DATE('now')"
  )
  suspend fun getTotalMinutesToday(): Int?
  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(exception: TemporaryException)
  @Delete suspend fun delete(exception: TemporaryException)
  @Query("DELETE FROM temporary_exceptions WHERE packageName = :packageName")
  suspend fun deleteByPackage(packageName: String)
  @Query(
          "DELETE FROM temporary_exceptions WHERE createdAt < :cutoffTime OR (startTime + (durationMinutes * 60 * 1000)) < :currentTime"
  )
  suspend fun deleteExpired(cutoffTime: Long, currentTime: Long)
}
