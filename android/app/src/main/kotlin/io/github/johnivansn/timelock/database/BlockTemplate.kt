package io.github.johnivansn.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "block_templates")
data class BlockTemplate(
        @PrimaryKey val id: String,
        val name: String,
        val type: String,
        val payloadJson: String,
        val createdAt: Long = System.currentTimeMillis()
)

