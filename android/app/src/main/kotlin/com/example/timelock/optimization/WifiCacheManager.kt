package com.example.timelock.optimization

import android.content.Context
import android.util.Log
import com.example.timelock.database.AppDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class WifiCacheManager(private val context: Context) {
  private val database = AppDatabase.getDatabase(context)
  private val prefs = context.getSharedPreferences("wifi_cache", Context.MODE_PRIVATE)

  companion object {
    private const val KEY_CACHED_NETWORKS = "cached_networks"
    private const val KEY_LAST_UPDATE = "last_update"
    private const val CACHE_VALIDITY_MS = 60 * 60 * 1000L
  }

  suspend fun getCachedNetworks(): List<String>? =
          withContext(Dispatchers.IO) {
            try {
              val lastUpdate = prefs.getLong(KEY_LAST_UPDATE, 0L)
              val now = System.currentTimeMillis()

              if (now - lastUpdate > CACHE_VALIDITY_MS) {
                Log.d("WifiCacheManager", "WiFi cache expired")
                return@withContext null
              }

              val cached = prefs.getStringSet(KEY_CACHED_NETWORKS, null)
              if (cached != null) {
                Log.d("WifiCacheManager", "Loaded ${cached.size} networks from cache")
                return@withContext cached.sorted()
              }

              null
            } catch (e: Exception) {
              Log.e("WifiCacheManager", "Error reading WiFi cache", e)
              null
            }
          }

  suspend fun cacheNetworks(networks: List<String>) =
          withContext(Dispatchers.IO) {
            try {
              prefs.edit()
                      .putStringSet(KEY_CACHED_NETWORKS, networks.toSet())
                      .putLong(KEY_LAST_UPDATE, System.currentTimeMillis())
                      .apply()

              Log.d("WifiCacheManager", "Cached ${networks.size} WiFi networks")
            } catch (e: Exception) {
              Log.e("WifiCacheManager", "Error caching WiFi networks", e)
            }
          }

  suspend fun addNetworkToCache(ssid: String) =
          withContext(Dispatchers.IO) {
            try {
              val current =
                      prefs.getStringSet(KEY_CACHED_NETWORKS, null)?.toMutableSet()
                              ?: mutableSetOf()
              if (current.add(ssid)) {
                prefs.edit()
                        .putStringSet(KEY_CACHED_NETWORKS, current)
                        .putLong(KEY_LAST_UPDATE, System.currentTimeMillis())
                        .apply()
                Log.d("WifiCacheManager", "Added $ssid to cache")
              }
            } catch (e: Exception) {
              Log.e("WifiCacheManager", "Error adding network to cache", e)
            }
          }

  suspend fun invalidateCache() =
          withContext(Dispatchers.IO) {
            try {
              prefs.edit().remove(KEY_CACHED_NETWORKS).remove(KEY_LAST_UPDATE).apply()
              Log.d("WifiCacheManager", "WiFi cache invalidated")
            } catch (e: Exception) {
              Log.e("WifiCacheManager", "Error invalidating cache", e)
            }
          }

  suspend fun mergeWithHistory(): List<String> =
          withContext(Dispatchers.IO) {
            try {
              val cached = getCachedNetworks() ?: emptyList()
              val history = database.wifiHistoryDao().getAll().map { it.ssid }
              val merged = (cached + history).distinct().sorted()

              cacheNetworks(merged)
              Log.d("WifiCacheManager", "Merged ${merged.size} unique networks")
              merged
            } catch (e: Exception) {
              Log.e("WifiCacheManager", "Error merging with history", e)
              emptyList()
            }
          }
}
