package com.example.timelock.database

import androidx.room.*

@Entity(tableName = "wifi_history")
data class WifiHistory(@PrimaryKey val ssid: String, val firstSeen: Long, val lastSeen: Long)

@Dao
interface WifiHistoryDao {
  @Query("SELECT * FROM wifi_history ORDER BY lastSeen DESC")
  suspend fun getAll(): List<WifiHistory>

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(wifiHistory: WifiHistory)

  @Query("UPDATE wifi_history SET lastSeen = :timestamp WHERE ssid = :ssid")
  suspend fun updateLastSeen(ssid: String, timestamp: Long)

  @Query("DELETE FROM wifi_history WHERE lastSeen < :threshold")
  suspend fun deleteOldEntries(threshold: Long)
}
