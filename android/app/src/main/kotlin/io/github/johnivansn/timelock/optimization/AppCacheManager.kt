package io.github.johnivansn.timelock.optimization

import android.app.ActivityManager
import android.content.Context
import android.graphics.drawable.Drawable
import android.os.PowerManager
import android.util.Log
import io.github.johnivansn.timelock.utils.AppUtils
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AppCacheManager(private val context: Context) {
  private val cacheDir = File(context.cacheDir, "app_cache")
  private val prefs = context.getSharedPreferences("app_cache", Context.MODE_PRIVATE)

  companion object {
    private const val KEY_LAST_CACHE_UPDATE = "last_cache_update"
    private const val CACHE_VALIDITY_MS = 24 * 60 * 60 * 1000L
  }

  init {
    if (!cacheDir.exists()) {
      cacheDir.mkdirs()
    }
  }

  suspend fun getCachedInstalledApps(): List<Map<String, String>>? =
          withContext(Dispatchers.IO) {
            try {
              val lastUpdate = prefs.getLong(KEY_LAST_CACHE_UPDATE, 0L)
              val now = System.currentTimeMillis()

              if (now - lastUpdate > CACHE_VALIDITY_MS) {
                Log.d("AppCacheManager", "Cache expired, needs refresh")
                return@withContext null
              }

              val cacheFile = File(cacheDir, "installed_apps.cache")
              if (!cacheFile.exists()) {
                return@withContext null
              }

              val apps = mutableListOf<Map<String, String>>()
              cacheFile.readLines().forEach { line ->
                val parts = line.split("|")
                if (parts.size == 2) {
                  apps.add(mapOf("packageName" to parts[0], "appName" to parts[1]))
                }
              }

              Log.d("AppCacheManager", "Loaded ${apps.size} apps from cache")
              apps
            } catch (e: Exception) {
              Log.e("AppCacheManager", "Error reading cache", e)
              null
            }
          }

  suspend fun cacheInstalledApps(apps: List<Map<String, String>>) =
          withContext(Dispatchers.IO) {
            try {
              val cacheFile = File(cacheDir, "installed_apps.cache")
              cacheFile.writeText(
                      apps.joinToString("\n") { "${it["packageName"]}|${it["appName"]}" }
              )

              prefs.edit().putLong(KEY_LAST_CACHE_UPDATE, System.currentTimeMillis()).apply()
              Log.d("AppCacheManager", "Cached ${apps.size} apps")
            } catch (e: Exception) {
              Log.e("AppCacheManager", "Error writing cache", e)
            }
          }

  suspend fun cacheAppIcon(packageName: String, drawable: Drawable) =
          withContext(Dispatchers.IO) {
            try {
              val iconFile = File(cacheDir, "$packageName.png")
              val bitmap = AppUtils.drawableToBitmap(drawable)
              FileOutputStream(iconFile).use { out ->
                bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 85, out)
              }
              trimIconCache()
              Log.d("AppCacheManager", "Cached icon for $packageName")
            } catch (e: Exception) {
              Log.e("AppCacheManager", "Error caching icon", e)
            }
          }

  fun getCachedIconBytes(packageName: String): ByteArray? {
    return try {
      val iconFile = File(cacheDir, "$packageName.png")
      if (iconFile.exists()) iconFile.readBytes() else null
    } catch (_: Exception) {
      null
    }
  }

  fun cacheIconBytes(packageName: String, bytes: ByteArray) {
    try {
      val iconFile = File(cacheDir, "$packageName.png")
      FileOutputStream(iconFile).use { it.write(bytes) }
      trimIconCache()
    } catch (_: Exception) {
      // Ignore cache write failures.
    }
  }

  private fun trimIconCache() {
    try {
      val files =
              cacheDir.listFiles { _, name -> name.endsWith(".png") }?.toMutableList()
                      ?: return
      var total = files.sumOf { it.length() }
      val maxBytes = maxCacheBytes()
      if (total <= maxBytes) return

      files.sortBy { it.lastModified() }
      for (file in files) {
        if (total <= maxBytes) break
        val size = file.length()
        if (file.delete()) {
          total -= size
        }
      }
    } catch (_: Exception) {
      // Best-effort cache trimming.
    }
  }

  private fun maxCacheBytes(): Long {
    val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    val memoryClass = am.memoryClass
    val base =
            when {
              memoryClass <= 256 -> 5L * 1024 * 1024
              memoryClass <= 384 -> 10L * 1024 * 1024
              else -> 20L * 1024 * 1024
            }
    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    return if (pm.isPowerSaveMode) (base * 0.6).toLong() else base
  }

  fun getCachedIconPath(packageName: String): String? {
    val iconFile = File(cacheDir, "$packageName.png")
    return if (iconFile.exists()) iconFile.absolutePath else null
  }

  suspend fun invalidateCache() =
          withContext(Dispatchers.IO) {
            try {
              cacheDir.listFiles()?.forEach { it.delete() }
              prefs.edit().remove(KEY_LAST_CACHE_UPDATE).apply()
              Log.d("AppCacheManager", "Cache invalidated")
            } catch (e: Exception) {
              Log.e("AppCacheManager", "Error invalidating cache", e)
            }
          }

  suspend fun getCacheSize(): Long =
          withContext(Dispatchers.IO) {
            try {
              cacheDir.listFiles()?.sumOf { it.length() } ?: 0L
            } catch (e: Exception) {
              0L
            }
          }
}

