package com.example.safety_protection_system

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.safety_protection_system/wifi"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Minta izin notifikasi (Android 13+) & izin Floating Overlay (Android 6+)
        requestNotificationPermission()
        requestOverlayPermission()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                try {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:$packageName")
                    )
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Gagal membuka izin overlay: ${e.message}")
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openWifiSettings") {
                try {
                    val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Gagal membuka pengaturan Wi-Fi: ${e.message}", null)
                }
            } else if (call.method == "triggerNativeNotification") {
                try {
                    val seatId = call.argument<String>("seatId") ?: "Penumpang"
                    BusNotificationService.showNotification(this, seatId)
                    result.success(true)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Gagal menayangkan notifikasi native: ${e.message}")
                    result.error("FAILED", "Gagal menayangkan notifikasi: ${e.message}", null)
                }
            } else if (call.method == "startBackgroundService") {
                try {
                    android.util.Log.d("MainActivity", "Memulai background foreground service pemantau notifikasi...")
                    val intent = Intent(this, BusNotificationService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.startForegroundService(this, intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Gagal memulai background service: ${e.message}")
                    result.error("FAILED", "Gagal memulai service: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
