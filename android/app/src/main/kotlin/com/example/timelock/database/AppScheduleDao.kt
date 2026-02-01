package com.example.timelock.database

import androidx.room.*

@Dao
interface AppScheduleDao {
  @Query("SELECT * FROM app_schedules WHERE packageName = :packageName AND isEnabled = 1")
  suspend fun getByPackage(packageName: String): List<AppSchedule>

  @Query("SELECT * FROM app_schedules WHERE isEnabled = 1")
  suspend fun getAllEnabled(): List<AppSchedule>

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(schedule: AppSchedule)

  @Update suspend fun update(schedule: AppSchedule)

  @Delete suspend fun delete(schedule: AppSchedule)

  @Query("DELETE FROM app_schedules WHERE packageName = :packageName")
  suspend fun deleteByPackage(packageName: String)
}
