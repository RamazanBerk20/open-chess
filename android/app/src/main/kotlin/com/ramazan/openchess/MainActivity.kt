package com.ramazan.openchess

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // mDNS (LAN game discovery) relies on multicast, which Android filters to
    // save power unless a MulticastLock is held. Dart acquires it only while
    // browsing or hosting a lobby (channel "open_chess/multicast"), and it is
    // always released when the activity goes away.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "open_chess/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        lock().let { if (!it.isHeld) it.acquire() }
                        result.success(null)
                    }
                    "release" -> {
                        multicastLock?.let { if (it.isHeld) it.release() }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun lock(): WifiManager.MulticastLock =
        multicastLock ?: (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
            .createMulticastLock("open-chess-mdns")
            .apply { setReferenceCounted(false) }
            .also { multicastLock = it }

    override fun onDestroy() {
        multicastLock?.let { if (it.isHeld) it.release() }
        multicastLock = null
        super.onDestroy()
    }
}
