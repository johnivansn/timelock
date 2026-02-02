package com.example.timelock.monitoring

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.util.Log
import com.example.timelock.blocking.BlockingEngine
import com.example.timelock.database.AppDatabase
import com.example.timelock.database.WifiHistory
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class NetworkMonitor(private val context: Context, private val scope: CoroutineScope) {
  private val connectivityManager =
          context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
  private val wifiManager =
          context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
  private val database = AppDatabase.getDatabase(context)
  private val blockingEngine = BlockingEngine(context)
  private var currentSSID: String? = null
  private var lastWifiCheckTime = 0L
  private val wifiCheckInterval = 5000L // Check every 5 seconds max

  private val networkCallback =
          object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
              super.onAvailable(network)
              val caps = connectivityManager.getNetworkCapabilities(network) ?: return
              if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return
              refreshSSID()
            }

            override fun onLost(network: Network) {
              super.onLost(network)
              handleDisconnect()
            }

            override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities
            ) {
              super.onCapabilitiesChanged(network, networkCapabilities)
              if (networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                refreshSSID()
              }
            }
          }

  fun start() {
    val request =
            NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build()
    connectivityManager.registerNetworkCallback(request, networkCallback)
    refreshSSID()
    scope.launch(Dispatchers.IO) { cleanupOldWifiHistory() }
    Log.i("NetworkMonitor", "Started")
  }

  fun stop() {
    try {
      connectivityManager.unregisterNetworkCallback(networkCallback)
    } catch (_: Exception) {}
    Log.i("NetworkMonitor", "Stopped")
  }

  fun getCurrentSSID(): String? {
    val now = System.currentTimeMillis()
    if (now - lastWifiCheckTime < wifiCheckInterval && currentSSID != null) {
      return currentSSID
    }
    lastWifiCheckTime = now

    return try {
      @Suppress("DEPRECATION") val wifiInfo = wifiManager.connectionInfo

      if (wifiInfo != null && wifiInfo.networkId != -1) {
        val ssid = wifiInfo.ssid?.removeSurrounding("\"")
        if (!ssid.isNullOrEmpty() && ssid != "<unknown ssid>" && ssid != "0x") {
          Log.d("NetworkMonitor", "WiFi SSID obtenido: $ssid")
          return ssid
        }
      }

      val activeNetwork = connectivityManager.activeNetwork
      if (activeNetwork != null) {
        val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
        if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
          val networkId = wifiInfo?.networkId ?: -1
          if (networkId != -1) {
            val stableId = "WiFi_Network_$networkId"
            Log.d("NetworkMonitor", "WiFi conectada, usando ID estable: $stableId")
            return stableId
          }
        }
      }

      Log.d("NetworkMonitor", "No hay conexión WiFi")
      null
    } catch (e: Exception) {
      Log.e("NetworkMonitor", "Error obteniendo SSID", e)
      null
    }
  }

  private fun refreshSSID() {
    val ssid = getCurrentSSID()

    if (ssid == currentSSID) return

    Log.i("NetworkMonitor", "SSID changed: $currentSSID -> $ssid")
    val previousSSID = currentSSID
    currentSSID = ssid

    if (ssid != null) {
      handleConnect(ssid)
      recordWifiHistory(ssid)
    } else if (previousSSID != null) {
      handleDisconnect()
    }
  }

  private fun recordWifiHistory(ssid: String) {
    // Don't record generic IDs
    if (ssid.startsWith("WiFi_Network_")) return

    scope.launch(Dispatchers.IO) {
      try {
        val existing = database.wifiHistoryDao().getAll().find { it.ssid == ssid }
        val now = System.currentTimeMillis()
        if (existing != null) {
          database.wifiHistoryDao().updateLastSeen(ssid, now)
        } else {
          database.wifiHistoryDao().insert(WifiHistory(ssid, now, now))
        }
        Log.d("NetworkMonitor", "Recorded WiFi: $ssid")
      } catch (e: Exception) {
        Log.e("NetworkMonitor", "Failed to record WiFi history", e)
      }
    }
  }

  private suspend fun cleanupOldWifiHistory() {
    try {
      val thirtyDaysAgo = System.currentTimeMillis() - TimeUnit.DAYS.toMillis(30)
      database.wifiHistoryDao().deleteOldEntries(thirtyDaysAgo)
      Log.d("NetworkMonitor", "Cleaned old WiFi history")
    } catch (e: Exception) {
      Log.e("NetworkMonitor", "Failed to cleanup WiFi history", e)
    }
  }

  private fun handleConnect(ssid: String) {
    scope.launch(Dispatchers.IO) {
      val restrictions = database.appRestrictionDao().getEnabled()
      for (restriction in restrictions) {
        val blockedSSIDs = restriction.getBlockedWifiList()

        val isBlocked =
                blockedSSIDs.any { blocked ->
                  blocked == ssid ||
                          (ssid.startsWith("WiFi_Network_") && blocked.startsWith("WiFi_Network_"))
                }

        if (isBlocked) {
          val blocked =
                  blockingEngine.blockApp(
                          restriction.packageName,
                          BlockingEngine.BlockReason.WifiBlocked
                  )
          if (blocked) Log.i("NetworkMonitor", "${restriction.packageName} blocked by WiFi: $ssid")
        }
      }
    }
  }

  private fun handleDisconnect() {
    scope.launch(Dispatchers.IO) {
      val restrictions = database.appRestrictionDao().getEnabled()
      for (restriction in restrictions) {
        if (restriction.getBlockedWifiList().isEmpty()) continue

        if (!blockingEngine.isQuotaBlocked(restriction.packageName)) {
          blockingEngine.unblockApp(restriction.packageName)
          Log.i("NetworkMonitor", "${restriction.packageName} unblocked - left WiFi")
        }
      }
    }
  }
}
