package io.github.johnivansn.timelock.admin

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class DeviceAdminManager : DeviceAdminReceiver() {
  override fun onEnabled(context: Context, intent: Intent) {
    super.onEnabled(context, intent)
    Log.i("DeviceAdmin", "Device admin enabled")
  }

  override fun onDisabled(context: Context, intent: Intent) {
    super.onDisabled(context, intent)
    Log.i("DeviceAdmin", "Device admin disabled")
  }

  override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
    return "Desactivar protección contra desinstalación deshabilitará las restricciones de apps"
  }
}

