package com.kidsafe.kidsafe

import android.content.Intent
import android.net.VpnService
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * KidSafe VPN client.
 *
 * Establishes a WireGuard tunnel to the family VPS using the config baked into
 * res/raw/wg_tunnel.conf, so ALL of the phone's traffic flows through the
 * server, where the deny list drops WhatsApp / YouTube. Nothing is blocked on
 * the device itself — the filtering is entirely network-side.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.kidsafe/vpn"
    private val vpnRequestCode = 0x0f1e
    private val tunnelName = "kidsafe"

    private var backend: GoBackend? = null
    private var tunnel: Tunnel? = null
    private var channel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        backend = GoBackend(applicationContext)
        tunnel = object : Tunnel {
            override fun getName(): String = tunnelName
            override fun onStateChange(newState: Tunnel.State) { /* polled from Dart */ }
        }

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> connect(result)
                "disconnect" -> disconnect(result)
                "status" -> result.success(currentState())
                else -> result.notImplemented()
            }
        }
    }

    private fun currentState(): String = try {
        if (backend?.getState(tunnel!!) == Tunnel.State.UP) "UP" else "DOWN"
    } catch (e: Exception) {
        "DOWN"
    }

    private fun loadConfig(): Config =
        resources.openRawResource(R.raw.wg_tunnel).use { input ->
            BufferedReader(InputStreamReader(input)).use { Config.parse(it) }
        }

    /** Ask for VPN consent if needed, then bring the tunnel up. */
    private fun connect(result: MethodChannel.Result) {
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            pendingResult = result
            startActivityForResult(prepareIntent, vpnRequestCode)
        } else {
            bringUp(result)
        }
    }

    private fun bringUp(result: MethodChannel.Result) {
        val config = try {
            loadConfig()
        } catch (e: Exception) {
            result.error("CONFIG", "Bad tunnel config: ${e.message}", null)
            return
        }
        // Backend I/O must not run on the UI thread.
        Thread {
            try {
                backend?.setState(tunnel!!, Tunnel.State.UP, config)
                runOnUiThread { result.success("UP") }
            } catch (e: Exception) {
                runOnUiThread { result.error("CONNECT", e.message, null) }
            }
        }.start()
    }

    private fun disconnect(result: MethodChannel.Result) {
        Thread {
            try {
                backend?.setState(tunnel!!, Tunnel.State.DOWN, null)
                runOnUiThread { result.success("DOWN") }
            } catch (e: Exception) {
                runOnUiThread { result.error("DISCONNECT", e.message, null) }
            }
        }.start()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == vpnRequestCode) {
            val result = pendingResult
            pendingResult = null
            if (resultCode == RESULT_OK && result != null) {
                bringUp(result)
            } else {
                result?.error("PERMISSION", "VPN permission was denied", null)
            }
        }
    }
}
