package com.example.timelock.admin

import android.content.Context
import android.util.Log
import com.example.timelock.database.AdminSettings
import com.example.timelock.database.AppDatabase
import java.security.MessageDigest

class AdminManager(context: Context) {
  private val database = AppDatabase.getDatabase(context)

  companion object {
    private const val MAX_ATTEMPTS = 3
    private const val LOCKOUT_DURATION_MS = 5L * 60 * 1000
    private const val RECOVERY_DURATION_MS = 24L * 60 * 60 * 1000
    private const val RECOVERY_WITH_QUESTION_MS = 12L * 60 * 60 * 1000
    private const val MAX_RECOVERY_ATTEMPTS = 10
  }

  private fun hashPin(pin: String): String {
    val bytes = MessageDigest.getInstance("SHA-256").digest(pin.toByteArray(Charsets.UTF_8))
    return bytes.joinToString("") { "%02x".format(it) }
  }

  suspend fun isAdminEnabled(): Boolean {
    val settings = database.adminSettingsDao().get() ?: return false
    return settings.isEnabled
  }

  suspend fun setupPin(
          pin: String,
          securityQuestion: String? = null,
          securityAnswer: String? = null
  ): Boolean {
    if (pin.length < 4 || pin.length > 6) return false
    if (!pin.all { it.isDigit() }) return false

    val answerHash =
            if (securityQuestion != null && securityAnswer != null) {
              hashPin(securityAnswer.lowercase().trim())
            } else null

    val settings =
            AdminSettings(
                    id = 1,
                    isEnabled = true,
                    pinHash = hashPin(pin),
                    failedAttempts = 0,
                    lockedUntil = 0L,
                    recoveryMode = false,
                    recoveryStartTime = 0L,
                    securityQuestion = securityQuestion,
                    securityAnswerHash = answerHash,
                    recoveryEmail = null
            )
    database.adminSettingsDao().upsert(settings)
    Log.i("AdminManager", "PIN setup completed")
    return true
  }

  suspend fun verifyPin(pin: String): VerifyResult {
    val settings = database.adminSettingsDao().get() ?: return VerifyResult.NOT_ENABLED

    if (!settings.isEnabled) return VerifyResult.NOT_ENABLED

    if (settings.recoveryMode) {
      return VerifyResult.IN_RECOVERY
    }

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
    return VerifyResult.WrongPin(remaining, newAttempts >= MAX_RECOVERY_ATTEMPTS)
  }

  suspend fun startRecoveryMode(): RecoveryResult {
    val settings =
            database.adminSettingsDao().get() ?: return RecoveryResult.Error("Admin not enabled")

    if (!settings.isEnabled) return RecoveryResult.Error("Admin not enabled")
    if (settings.recoveryMode) return RecoveryResult.AlreadyInRecovery

    val now = System.currentTimeMillis()
    val duration =
            if (settings.securityQuestion != null) RECOVERY_WITH_QUESTION_MS
            else RECOVERY_DURATION_MS

    database.adminSettingsDao()
            .upsert(
                    settings.copy(
                            recoveryMode = true,
                            recoveryStartTime = now,
                            failedAttempts = 0,
                            lockedUntil = 0L
                    )
            )

    Log.i("AdminManager", "Recovery mode started, duration: ${duration / 1000 / 60 / 60}h")
    return RecoveryResult.Started(duration)
  }

  suspend fun getRecoveryStatus(): RecoveryStatus {
    val settings = database.adminSettingsDao().get() ?: return RecoveryStatus.NotInRecovery

    if (!settings.recoveryMode) return RecoveryStatus.NotInRecovery

    val now = System.currentTimeMillis()
    val elapsed = now - settings.recoveryStartTime
    val duration =
            if (settings.securityQuestion != null) RECOVERY_WITH_QUESTION_MS
            else RECOVERY_DURATION_MS
    val remaining = duration - elapsed

    return if (remaining <= 0) {
      RecoveryStatus.Ready(settings.securityQuestion)
    } else {
      RecoveryStatus.InProgress(remaining, settings.securityQuestion)
    }
  }

  suspend fun verifySecurityAnswer(answer: String): Boolean {
    val settings = database.adminSettingsDao().get() ?: return false
    if (settings.securityAnswerHash == null) return false

    return hashPin(answer.lowercase().trim()) == settings.securityAnswerHash
  }

  suspend fun completeRecovery(
          newPin: String,
          securityAnswer: String? = null
  ): RecoveryCompleteResult {
    val settings =
            database.adminSettingsDao().get()
                    ?: return RecoveryCompleteResult.Error("Admin not enabled")

    if (!settings.recoveryMode) return RecoveryCompleteResult.Error("Not in recovery mode")

    if (settings.securityQuestion != null && securityAnswer != null) {
      if (!verifySecurityAnswer(securityAnswer)) {
        return RecoveryCompleteResult.WrongAnswer
      }
    } else {
      val status = getRecoveryStatus()
      if (status !is RecoveryStatus.Ready) {
        return RecoveryCompleteResult.Error("Recovery period not complete")
      }
    }

    if (newPin.length < 4 || newPin.length > 6 || !newPin.all { it.isDigit() }) {
      return RecoveryCompleteResult.Error("Invalid PIN format")
    }

    database.adminSettingsDao()
            .upsert(
                    settings.copy(
                            pinHash = hashPin(newPin),
                            recoveryMode = false,
                            recoveryStartTime = 0L,
                            failedAttempts = 0,
                            lockedUntil = 0L
                    )
            )

    Log.i("AdminManager", "Recovery completed, new PIN set")
    return RecoveryCompleteResult.Success
  }

  suspend fun cancelRecovery(): Boolean {
    val settings = database.adminSettingsDao().get() ?: return false
    if (!settings.recoveryMode) return false

    database.adminSettingsDao().upsert(settings.copy(recoveryMode = false, recoveryStartTime = 0L))
    Log.i("AdminManager", "Recovery cancelled")
    return true
  }

  suspend fun disableAdmin(): Boolean {
    val settings = database.adminSettingsDao().get() ?: return false
    database.adminSettingsDao()
            .upsert(
                    settings.copy(
                            isEnabled = false,
                            pinHash = "",
                            failedAttempts = 0,
                            lockedUntil = 0L,
                            recoveryMode = false,
                            recoveryStartTime = 0L
                    )
            )
    Log.i("AdminManager", "Admin mode disabled")
    return true
  }

  sealed class VerifyResult {
    object SUCCESS : VerifyResult()
    object NOT_ENABLED : VerifyResult()
    object IN_RECOVERY : VerifyResult()
    data class WrongPin(val attemptsRemaining: Int, val canStartRecovery: Boolean) : VerifyResult()
    data class Locked(val remainingSeconds: Int) : VerifyResult()
  }

  sealed class RecoveryResult {
    data class Started(val durationMs: Long) : RecoveryResult()
    object AlreadyInRecovery : RecoveryResult()
    data class Error(val message: String) : RecoveryResult()
  }

  sealed class RecoveryStatus {
    object NotInRecovery : RecoveryStatus()
    data class InProgress(val remainingMs: Long, val hasSecurityQuestion: String?) :
            RecoveryStatus()
    data class Ready(val hasSecurityQuestion: String?) : RecoveryStatus()
  }

  sealed class RecoveryCompleteResult {
    object Success : RecoveryCompleteResult()
    object WrongAnswer : RecoveryCompleteResult()
    data class Error(val message: String) : RecoveryCompleteResult()
  }
}
