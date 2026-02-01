package com.example.timelock.exceptions

import android.content.Context
import com.example.timelock.database.AppDatabase
import com.example.timelock.database.TemporaryException
import com.example.timelock.logging.ActivityLogger
import java.text.SimpleDateFormat
import java.util.*

class ExceptionManager(context: Context) {
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
  private val activityLogger = ActivityLogger(context)

  companion object {
    private const val MAX_EXCEPTIONS_PER_APP = 3
    private const val MAX_TOTAL_MINUTES = 60
  }

  suspend fun canGrantException(packageName: String): ExceptionResult {
    val today = dateFormat.format(Date())
    val count = database.temporaryExceptionDao().countForApp(packageName, today)

    if (count >= MAX_EXCEPTIONS_PER_APP) {
      return ExceptionResult.LimitReached(
              "Máximo $MAX_EXCEPTIONS_PER_APP excepciones por día alcanzado"
      )
    }

    val totalMinutes = database.temporaryExceptionDao().totalMinutesForDate(today) ?: 0
    if (totalMinutes >= MAX_TOTAL_MINUTES) {
      return ExceptionResult.LimitReached(
              "Tiempo total de excepciones agotado ($MAX_TOTAL_MINUTES minutos)"
      )
    }

    return ExceptionResult.Allowed(MAX_EXCEPTIONS_PER_APP - count, MAX_TOTAL_MINUTES - totalMinutes)
  }

  suspend fun grantException(
          packageName: String,
          appName: String,
          durationMinutes: Int
  ): ExceptionResult {
    val canGrant = canGrantException(packageName)
    if (canGrant !is ExceptionResult.Allowed) {
      return canGrant
    }

    val today = dateFormat.format(Date())
    val totalMinutes = database.temporaryExceptionDao().totalMinutesForDate(today) ?: 0

    if (totalMinutes + durationMinutes > MAX_TOTAL_MINUTES) {
      return ExceptionResult.LimitReached(
              "Excede tiempo total disponible (${MAX_TOTAL_MINUTES - totalMinutes} min restantes)"
      )
    }

    val exception =
            TemporaryException(
                    id = UUID.randomUUID().toString(),
                    packageName = packageName,
                    appName = appName,
                    startTime = System.currentTimeMillis(),
                    durationMinutes = durationMinutes,
                    date = today
            )

    database.temporaryExceptionDao().insert(exception)
    activityLogger.logException(packageName, appName, durationMinutes)

    return ExceptionResult.Granted(exception)
  }

  suspend fun getActiveException(packageName: String): TemporaryException? {
    val today = dateFormat.format(Date())
    val exceptions = database.temporaryExceptionDao().getForApp(packageName, today)
    return exceptions.firstOrNull { it.isActive() }
  }

  suspend fun getRemainingStats(packageName: String): ExceptionStats {
    val today = dateFormat.format(Date())
    val count = database.temporaryExceptionDao().countForApp(packageName, today)
    val appMinutes = database.temporaryExceptionDao().totalMinutesForApp(packageName, today) ?: 0
    val totalMinutes = database.temporaryExceptionDao().totalMinutesForDate(today) ?: 0

    return ExceptionStats(
            exceptionsUsed = count,
            exceptionsRemaining = MAX_EXCEPTIONS_PER_APP - count,
            minutesUsed = totalMinutes,
            minutesRemaining = MAX_TOTAL_MINUTES - totalMinutes,
            appMinutesUsed = appMinutes
    )
  }

  sealed class ExceptionResult {
    data class Allowed(val exceptionsLeft: Int, val minutesLeft: Int) : ExceptionResult()
    data class Granted(val exception: TemporaryException) : ExceptionResult()
    data class LimitReached(val reason: String) : ExceptionResult()
  }

  data class ExceptionStats(
          val exceptionsUsed: Int,
          val exceptionsRemaining: Int,
          val minutesUsed: Int,
          val minutesRemaining: Int,
          val appMinutesUsed: Int
  )
}
