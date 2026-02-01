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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class NetworkMonitor(private val context: Context) {
  private val connectivityManager =
          context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
  private val wifiManager =
          context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
  private val database = AppDatabase.getDatabase(context)
  private val blockingEngine = BlockingEngine(context)
  private val scope = CoroutineScope(Dispatchers.IO)
  private var currentSSID: String? = null

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
              val caps = connectivityManager.getNetworkCapabilities(network)
              if (caps != null && !caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return
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
    Log.i("NetworkMonitor", "Started")
  }

  fun stop() {
    try {
      connectivityManager.unregisterNetworkCallback(networkCallback)
    } catch (_: Exception) {}
    Log.i("NetworkMonitor", "Stopped")
  }

  fun getCurrentSSID(): String? {
    return getCurrentSSIDDirect()
  }

  private fun getCurrentSSIDDirect(): String? {
    val info = wifiManager.connectionInfo ?: return null
    if (info.networkId == -1) return null
    val ssid = info.ssid ?: return null
    return ssid.removeSurrounding("\"")
  }

  private fun refreshSSID() {
    val ssid = getCurrentSSIDDirect()
    if (ssid == currentSSID) return
    Log.i("NetworkMonitor", "SSID changed: ${currentSSID} -> $ssid")
    currentSSID = ssid
    if (ssid != null) {
      handleConnect(ssid)
    } else {
      handleDisconnect()
    }
  }

  private fun handleConnect(ssid: String) {
    scope.launch {
      val restrictions = database.appRestrictionDao().getEnabled()
      for (restriction in restrictions) {
        val blockedSSIDs = restriction.getBlockedWifiList()
        if (ssid in blockedSSIDs) {
          blockingEngine.blockApp(restriction.packageName) { success ->
            if (success) {
              Log.i("NetworkMonitor", "${restriction.packageName} blocked by WiFi: $ssid")
            }
          }
        }
      }
    }
  }

  private fun handleDisconnect() {
    scope.launch {
      val restrictions = database.appRestrictionDao().getEnabled()
      for (restriction in restrictions) {
        val blockedSSIDs = restriction.getBlockedWifiList()
        if (blockedSSIDs.isNotEmpty()) {
          val stillOnBlockedWifi = currentSSID != null && currentSSID in blockedSSIDs
          if (!stillOnBlockedWifi) {
            val quotaBlocked = blockingEngine.isQuotaBlocked(restriction.packageName)
            if (!quotaBlocked) {
              blockingEngine.unblockApp(restriction.packageName)
              Log.i("NetworkMonitor", "${restriction.packageName} unblocked - left WiFi")
            }
          }
        }
      }
    }
  }
}
