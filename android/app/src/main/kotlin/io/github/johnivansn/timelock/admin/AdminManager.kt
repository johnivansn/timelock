package io.github.johnivansn.timelock.admin

import android.content.Context
import android.util.Log
import io.github.johnivansn.timelock.database.AdminSettings
import io.github.johnivansn.timelock.database.AppDatabase
import java.security.MessageDigest

class AdminManager(context: Context) {
  private val database = AppDatabase.getDatabase(context)

  companion object {
    private const val MAX_ATTEMPTS = 3
    private const val LOCKOUT_DURATION_MS = 5L * 60 * 1000
  }

  private fun hashPin(pin: String): String {
    val bytes = MessageDigest.getInstance("SHA-256").digest(pin.toByteArray(Charsets.UTF_8))
    return bytes.joinToString("") { "%02x".format(it) }
  }

  suspend fun isAdminEnabled(): Boolean {
    val settings = database.adminSettingsDao().get() ?: return false
    return settings.isEnabled
  }

  suspend fun setupPin(pin: String): Boolean {
    if (pin.length != 4) return false
    if (!pin.all { it.isDigit() }) return false

    val settings =
            AdminSettings(
                    id = 1,
                    isEnabled = true,
                    pinHash = hashPin(pin),
                    failedAttempts = 0,
                    lockedUntil = 0L
            )
    database.adminSettingsDao().upsert(settings)
    Log.i("AdminManager", "PIN setup completed")
    return true
  }

  suspend fun verifyPin(pin: String): VerifyResult {
    val settings = database.adminSettingsDao().get() ?: return VerifyResult.NOT_ENABLED

    if (!settings.isEnabled) return VerifyResult.NOT_ENABLED

    val now = System.currentTimeMillis()
    if (settings.lockedUntil > now) {
      val remainingMs = settings.lockedUntil - now
      val remainingSec = ((remainingMs + 999) / 1000).toInt()
      return VerifyResult.Locked(remainingSec)
    }

    if (hashPin(pin) == settings.pinHash) {
      if (settings.failedAttempts > 0) {
        database.adminSettingsDao().upsert(settings.copy(failedAttempts = 0))
      }
      Log.i("AdminManager", "PIN verified successfully")
      return VerifyResult.SUCCESS
    }

    val newAttempts = settings.failedAttempts + 1
    if (newAttempts >= MAX_ATTEMPTS) {
      val lockUntil = now + LOCKOUT_DURATION_MS
      database.adminSettingsDao().upsert(settings.copy(failedAttempts = 0, lockedUntil = lockUntil))
      Log.w("AdminManager", "PIN locked for 5 minutes after $MAX_ATTEMPTS failed attempts")
      return VerifyResult.Locked(5 * 60)
    }

    database.adminSettingsDao().upsert(settings.copy(failedAttempts = newAttempts))
    val remaining = MAX_ATTEMPTS - newAttempts
    Log.w("AdminManager", "PIN incorrect, $remaining attempts remaining")
    return VerifyResult.WrongPin(remaining)
  }

  suspend fun disableAdmin(): Boolean {
    val settings = database.adminSettingsDao().get() ?: return false
    database.adminSettingsDao()
            .upsert(
                    settings.copy(
                            isEnabled = false,
                            pinHash = "",
                            failedAttempts = 0,
                            lockedUntil = 0L
                    )
            )
    Log.i("AdminManager", "Admin mode disabled")
    return true
  }

  sealed class VerifyResult {
    object SUCCESS : VerifyResult()
    object NOT_ENABLED : VerifyResult()
    data class WrongPin(val attemptsRemaining: Int) : VerifyResult()
    data class Locked(val remainingSeconds: Int) : VerifyResult()
  }
}

