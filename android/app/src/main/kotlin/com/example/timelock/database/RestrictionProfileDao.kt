package com.example.timelock.database

import androidx.room.*

@Dao
interface RestrictionProfileDao {
  @Query("SELECT * FROM restriction_profiles ORDER BY createdAt ASC")
  suspend fun getAll(): List<RestrictionProfile>

  @Query("SELECT * FROM restriction_profiles WHERE id = :id LIMIT 1")
  suspend fun getById(id: String): RestrictionProfile?

  @Query("SELECT * FROM restriction_profiles WHERE isDefault = 1 LIMIT 1")
  suspend fun getDefault(): RestrictionProfile?

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(profile: RestrictionProfile)

  @Update suspend fun update(profile: RestrictionProfile)

  @Delete suspend fun delete(profile: RestrictionProfile)

  @Query("SELECT COUNT(*) FROM restriction_profiles") suspend fun count(): Int
}
