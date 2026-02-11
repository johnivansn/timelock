package io.github.johnivansn.timelock.database

import androidx.room.*

@Dao
interface AdminSettingsDao {
  @Query("SELECT * FROM admin_settings WHERE id = 1 LIMIT 1") suspend fun get(): AdminSettings?

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsert(settings: AdminSettings)
}

