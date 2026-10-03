package com.student.portfolio.portfolio_app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Nearby Connections needs dangerous permissions granted at runtime, plus the
 * device location toggle switched on. The nearby_connections plugin deliberately
 * requests nothing itself, so without this the platform calls fail with a
 * SecurityException and discovery silently finds nothing.
 *
 * Handled natively to avoid pulling in a permission plugin for four requests.
 */
class MainActivity : FlutterActivity() {

    private val channel = "portfolio_app/nearby"

    /** Permissions this Android version actually requires. */
    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: nearby-device permissions replace the legacy Bluetooth
            // trio, but Location is still required for peer discovery.
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
        } else {
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
        }

    private fun granted(permission: String) =
        ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED

    private fun missingPermissions(): List<String> =
        requiredPermissions().filterNot { granted(it) }

    /**
     * Location services must be enabled at the OS level. Bluetooth on is handled
     * by the system once we hold BLUETOOTH_CONNECT, but the location toggle is a
     * separate switch the user has to flip themselves.
     */
    private fun isLocationEnabled(): Boolean {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            (manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "check" -> result.success(currentStatus())

                    "request" -> requestPermissions(result)

                    // The two blockers a runtime prompt cannot fix.
                    "openLocationSettings" -> {
                        startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                        result.success(null)
                    }

                    "openAppSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null),
                            )
                        )
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun currentStatus(): Map<String, Any?> {
        val missing = missingPermissions()
        return mapOf(
            "granted" to missing.isEmpty(),
            "missing" to missing,
            "locationEnabled" to isLocationEnabled(),
            "permanentlyDenied" to missing.any { isPermanentlyDenied(it) },
        )
    }

    /**
     * True when the user declined with "don't ask again", so another in-app
     * prompt would be ignored and only system settings can help.
     */
    private fun isPermanentlyDenied(permission: String): Boolean {
        if (granted(permission)) return false
        val asked = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!asked.getBoolean(permission, false)) {
            asked.edit().putBoolean(permission, true).apply()
            return false
        }
        // Asked before and no rationale offered: permanently denied.
        return !ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        val missing = missingPermissions()
        if (missing.isEmpty()) {
            result.success(currentStatus())
            return
        }
        // Held until onRequestPermissionsResult answers on the main thread.
        pendingResult = result
        ActivityCompat.requestPermissions(this, missing.toTypedArray(), REQUEST_CODE)
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return
        // This callback already runs on the main thread, which owns the channel.
        pendingResult?.success(currentStatus())
        pendingResult = null
    }

    companion object {
        private const val REQUEST_CODE = 4201
        private const val PREFS = "nearby_permission_prompts"
    }
}