package com.example.timelock.database

import androidx.room.*

@Dao
interface AppRestrictionDao {
  @Query("SELECT * FROM app_restrictions") suspend fun getAll(): List<AppRestriction>

  @Query("SELECT * FROM app_restrictions WHERE profileId = :profileId")
  suspend fun getAllForProfile(profileId: String): List<AppRestriction>

  @Query(
          "SELECT * FROM app_restrictions WHERE packageName = :packageName AND profileId = :profileId LIMIT 1"
  )
  suspend fun getByPackageAndProfile(packageName: String, profileId: String): AppRestriction?

  @Query("SELECT * FROM app_restrictions WHERE packageName = :packageName LIMIT 1")
  suspend fun getByPackage(packageName: String): AppRestriction?

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(restriction: AppRestriction)

  @Update suspend fun update(restriction: AppRestriction)

  @Delete suspend fun delete(restriction: AppRestriction)

  @Query("SELECT * FROM app_restrictions WHERE isEnabled = 1 AND profileId = :profileId")
  suspend fun getEnabledForProfile(profileId: String): List<AppRestriction>

  @Query("SELECT * FROM app_restrictions WHERE isEnabled = 1")
  suspend fun getEnabled(): List<AppRestriction>

  @Query("DELETE FROM app_restrictions WHERE profileId = :profileId")
  suspend fun deleteAllForProfile(profileId: String)
}
