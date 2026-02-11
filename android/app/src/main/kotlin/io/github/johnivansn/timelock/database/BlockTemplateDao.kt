package io.github.johnivansn.timelock.database

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update

@Dao
interface BlockTemplateDao {
  @Query("SELECT * FROM block_templates ORDER BY createdAt DESC")
  suspend fun getAll(): List<BlockTemplate>

  @Query("SELECT * FROM block_templates WHERE id = :id")
  suspend fun getById(id: String): BlockTemplate?

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(template: BlockTemplate)

  @Update suspend fun update(template: BlockTemplate)

  @Delete suspend fun delete(template: BlockTemplate)

  @Query("DELETE FROM block_templates WHERE id = :id")
  suspend fun deleteById(id: String)
}

