package io.github.johnivansn.timelock.database

import androidx.room.*

@Dao
interface AppRestrictionDao {
  @Query("SELECT * FROM app_restrictions") suspend fun getAll(): List<AppRestriction>

  @Query("SELECT * FROM app_restrictions WHERE packageName = :packageName LIMIT 1")
  suspend fun getByPackage(packageName: String): AppRestriction?

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(restriction: AppRestriction)

  @Update suspend fun update(restriction: AppRestriction)

  @Delete suspend fun delete(restriction: AppRestriction)

  @Query("SELECT * FROM app_restrictions WHERE isEnabled = 1")
  suspend fun getEnabled(): List<AppRestriction>
}

