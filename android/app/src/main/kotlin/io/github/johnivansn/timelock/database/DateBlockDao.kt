package io.github.johnivansn.timelock.database

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update

@Dao
interface DateBlockDao {
  @Query("SELECT * FROM date_blocks WHERE packageName = :packageName")
  suspend fun getByPackage(packageName: String): List<DateBlock>

  @Query("SELECT * FROM date_blocks")
  suspend fun getAll(): List<DateBlock>

  @Query("SELECT DISTINCT packageName FROM date_blocks")
  suspend fun getPackages(): List<String>

  @Query("SELECT * FROM date_blocks WHERE packageName = :packageName AND isEnabled = 1")
  suspend fun getEnabledByPackage(packageName: String): List<DateBlock>

  @Query("SELECT * FROM date_blocks WHERE id = :id")
  suspend fun getById(id: String): DateBlock?

  @Query(
          "SELECT * FROM date_blocks " +
                  "WHERE packageName = :packageName " +
                  "AND isEnabled = 1 " +
                  "AND :today BETWEEN startDate AND endDate " +
                  "ORDER BY endDate ASC"
  )
  suspend fun getActiveForDate(packageName: String, today: String): List<DateBlock>

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(block: DateBlock)

  @Update suspend fun update(block: DateBlock)

  @Delete suspend fun delete(block: DateBlock)

  @Query("DELETE FROM date_blocks WHERE packageName = :packageName")
  suspend fun deleteByPackage(packageName: String)
}

