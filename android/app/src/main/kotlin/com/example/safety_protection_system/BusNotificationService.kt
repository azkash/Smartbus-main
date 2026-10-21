package com.example.safety_protection_system

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import okhttp3.*
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class BusNotificationService : Service() {
    private val TAG = "BusNotificationService"
    private val NOTIFY_ID_SERVICE = 8880
    private val NOTIFY_ID_CALL = 8889

    private var okHttpClient: OkHttpClient? = null
    private var webSocket: WebSocket? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val callState = CallNotificationState()
    private var reconnectRunnable: Runnable? = null
    private var watchdogRunnable: Runnable? = null
    private var lastWsMessageTime: Long = System.currentTimeMillis()
    private var lastIp: String = "bus-led.local"

    // System Floating Overlay Window
    private var windowManager: WindowManager? = null
    private var floatingOverlayView: View? = null

    companion object {
        const val ACTION_CLEAR_CALL = "com.example.safety_protection_system.ACTION_CLEAR_CALL"
        const val EXTRA_SEAT_ID = "extra_seat_id"
        // Use a new channel ID because Android keeps a channel's original sound
        // setting after an app update. This guarantees existing installations
        // migrate from the old audible channel to this silent one.
        private const val CHANNEL_ALERT_SILENT = "bus_alert_silent_channel_v2"
        private var instance: BusNotificationService? = null

        fun getInstance(): BusNotificationService? = instance

        fun showNotification(context: Context, seatId: String) {
            instance?.addEmergencyCalls(CallNotificationState.parseSeatIds(seatId)) ?: run {
                showFallbackNotification(context, seatId)
            }
        }

        fun showFallbackNotification(context: Context, seatId: String) {
            try {
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }

                val clearIntent = Intent(context, BusNotificationService::class.java).apply {
                    action = ACTION_CLEAR_CALL
                    putExtra(EXTRA_SEAT_ID, seatId)
                }
                val pendingClear = PendingIntent.getService(context, 1, clearIntent, flags)

                val builder = NotificationCompat.Builder(context, CHANNEL_ALERT_SILENT)
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setContentTitle("🔔 PANGGILAN PENUMPANG BUS")
                    .setContentText("Kursi $seatId memerlukan bantuan!")
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setOnlyAlertOnce(true)
                    .setSound(null)
                    .setDefaults(0)
                    .setVibrate(longArrayOf(0, 500, 200, 500))
                    .addAction(android.R.drawable.ic_menu_close_clear_cancel, "✅ Matikan Bel ($seatId)", pendingClear)

                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(8889, builder.build())
            } catch (e: Exception) {
                Log.e("BusNotificationService", "Gagal menayangkan fallback notification: ${e.message}")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "Foreground Service & Floating Overlay Manager Created")
        createNotificationChannels()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // A restarted process has no in-memory call state. Remove any stale
        // call notification; the immediate roster request below restores it
        // only when the master still reports an active call.
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFY_ID_CALL)

        startForeground(NOTIFY_ID_SERVICE, buildForegroundServiceNotification())

        okHttpClient = OkHttpClient.Builder()
            .readTimeout(0, TimeUnit.MILLISECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            .connectTimeout(10, TimeUnit.SECONDS)
            .pingInterval(4, TimeUnit.SECONDS)
            .build()

        startWatchdog()
        scheduleReconnect(0)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CLEAR_CALL) {
            val seatId = intent.getStringExtra(EXTRA_SEAT_ID) ?: ""
            dismissCall(seatId)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        removeFloatingOverlay()
        reconnectRunnable?.let { mainHandler.removeCallbacks(it) }
        watchdogRunnable?.let { mainHandler.removeCallbacks(it) }
        disconnectWebSocket()
        Log.d(TAG, "Background Service Destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun addEmergencyCalls(seatIds: Collection<String>) {
        mainHandler.post {
            applyCallTransition(callState.addCalls(seatIds))
        }
    }

    private fun replaceEmergencyCalls(seatIds: Collection<String>) {
        mainHandler.post {
            applyCallTransition(callState.replaceWithSnapshot(seatIds))
        }
    }

    private fun clearEmergencyCalls(seatIds: Collection<String>) {
        mainHandler.post {
            applyCallTransition(callState.clearCalls(seatIds))
        }
    }

    private fun applyCallTransition(transition: CallNotificationState.Transition) {
        if (!transition.changed) return

        if (transition.active.isEmpty()) {
            removeFloatingOverlay()
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFY_ID_CALL)
            Log.d(TAG, "Semua panggilan selesai; notifikasi persistent dihapus")
            return
        }

        val seatText = transition.active.joinToString(", ")
        showFallbackNotification(applicationContext, seatText)
        showFloatingOverlay(transition.active)
        Log.d(
            TAG,
            "Status panggilan berubah: aktif=$seatText, baru=${transition.added}, selesai=${transition.removed}",
        )
    }

    // ================= FLOATING SYSTEM OVERLAY WINDOW =================
    private fun showFloatingOverlay(seatIds: Set<String>) {
        val seatId = seatIds.joinToString(", ")
        try {

                // Tampilkan Floating System Overlay Window (Melayang di atas semua app)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                    Log.d(TAG, "Izin SYSTEM_ALERT_WINDOW belum aktif, menggunakan Heads-Up Banner")
                    return
                }

                removeFloatingOverlay()

                // Buat Tampilan Floating Banner secara Programmatic (Modern Glassmorphic Pill)
                val density = resources.displayMetrics.density
                val dp = { value: Int -> (value * density).toInt() }

                val container = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(dp(16), dp(12), dp(16), dp(12))

                    // Background Rounded Gradient Amber
                    val bg = GradientDrawable(
                        GradientDrawable.Orientation.LEFT_RIGHT,
                        intArrayOf(Color.parseColor("#EA580C"), Color.parseColor("#D97706"))
                    ).apply {
                        cornerRadius = dp(20).toFloat()
                        setStroke(dp(2), Color.parseColor("#FDE047"))
                    }
                    background = bg
                    elevation = dp(12).toFloat()
                }

                // Icon Lonceng
                val icon = ImageView(this).apply {
                    setImageResource(android.R.drawable.ic_popup_reminder)
                    setColorFilter(Color.WHITE)
                    layoutParams = LinearLayout.LayoutParams(dp(28), dp(28)).apply {
                        marginEnd = dp(12)
                    }
                }
                container.addView(icon)

                // Teks Panggilan
                val textLayout = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
                }
                val title = TextView(this).apply {
                    text = "🔔 PANGGILAN BANTUAN BUS"
                    setTextColor(Color.WHITE)
                    textSize = 12f
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                }
                val subtitle = TextView(this).apply {
                    text = "Kursi $seatId memerlukan bantuan!"
                    setTextColor(Color.parseColor("#FEF3C7"))
                    textSize = 11f
                }
                textLayout.addView(title)
                textLayout.addView(subtitle)
                container.addView(textLayout)

                // Tombol "Oke / Matikan Bel"
                val btnOke = Button(this).apply {
                    text = if (seatIds.size == 1) "Oke $seatId" else "Oke Semua"
                    setTextColor(Color.parseColor("#B45309"))
                    textSize = 11f
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    val btnBg = GradientDrawable().apply {
                        setColor(Color.WHITE)
                        cornerRadius = dp(12).toFloat()
                    }
                    background = btnBg
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        dp(36)
                    ).apply {
                        marginStart = dp(12)
                    }
                    setOnClickListener {
                        dismissCall(seatId)
                    }
                }
                container.addView(btnOke)

                // Konfigurasi WindowManager
                val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    layoutType,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    y = dp(24)
                }

                floatingOverlayView = container
                windowManager?.addView(container, params)
                Log.d(TAG, "✨ Floating System Overlay Window berhasil ditampilkan di atas aplikasi lain!")

        } catch (e: Exception) {
            Log.e(TAG, "Gagal memunculkan Floating System Overlay Window: ${e.message}")
        }
    }

    private fun dismissCall(seatId: String) {
        val seatIds = CallNotificationState.parseSeatIds(seatId)
        if (seatIds.isEmpty()) return

        mainHandler.post {
            // Jika lebih dari 1 kursi atau semua kursi aktif di-clear, kirim id "all"
            // agar Master membersihkan seluruh panggilan secara atomik.
            if (seatIds.size > 1 || callState.snapshot().all { seatIds.contains(it) }) {
                val payloadAll = JSONObject()
                    .put("action", "clearCall")
                    .put("id", "all")
                    .toString()
                webSocket?.send(payloadAll)
            }
            // Kirim per-ID untuk kompatibilitas
            seatIds.forEach { id ->
                val payload = JSONObject()
                    .put("action", "clearCall")
                    .put("id", id)
                    .toString()
                webSocket?.send(payload)
            }
            applyCallTransition(callState.clearCalls(seatIds))
        }
    }

    private fun removeFloatingOverlay() {
        try {
            if (floatingOverlayView != null && windowManager != null) {
                windowManager?.removeView(floatingOverlayView)
                floatingOverlayView = null
            }
        } catch (e: Exception) {}
    }

    // ================= NOTIFICATION CHANNELS & SERVICE =================
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            val serviceChannel = NotificationChannel(
                "bus_service_channel",
                "Layanan Pemantau Bus",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Menjaga pemantauan kursi dan IoT bus tetap aktif di latar belakang"
                setShowBadge(false)
            }
            manager?.createNotificationChannel(serviceChannel)

            val alertChannel = NotificationChannel(
                CHANNEL_ALERT_SILENT,
                "Panggilan Bantuan Penumpang",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi visual tanpa suara ketika penumpang menekan tombol bantuan"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager?.createNotificationChannel(alertChannel)
        }
    }

    private fun buildForegroundServiceNotification(): Notification {
        return NotificationCompat.Builder(this, "bus_service_channel")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle("Smart Bus Controller")
            .setContentText("Sistem pemantau kursi & IoT aktif di latar belakang")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun readMqttHostFromPrefs(): String {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val cachedValue = prefs.getString("flutter.cached_esp_ip", "") ?: ""
            val cachedIp = if (cachedValue == "192.168.4.1") "" else cachedValue
            val savedHost = prefs.getString(
                "flutter.mqtt_host",
                "http://bus-led.local"
            ) ?: "http://bus-led.local"
            val host = if (cachedIp.isNotEmpty()) cachedIp else if (
                savedHost.contains("192.168.4.1")
            ) "http://bus-led.local" else savedHost

            var cleanHost = host.replace("http://", "").replace("https://", "").replace("ws://", "")
            if (cleanHost.contains(":")) {
                cleanHost = cleanHost.split(":")[0]
            }
            if (cleanHost.endsWith("/")) {
                cleanHost = cleanHost.substring(0, cleanHost.length - 1)
            }
            lastIp = cleanHost
            return cleanHost
        } catch (e: Exception) {
            Log.e(TAG, "Error membaca SharedPreferences: ${e.message}")
        }
        return lastIp
    }

    private fun connectWebSocket() {
        disconnectWebSocket()

        val ip = readMqttHostFromPrefs()
        if (ip.contains("emqx") || ip.contains("broker") || ip.contains("hivemq")) {
            scheduleReconnect(10000)
            return
        }

        val wsUrl = "ws://$ip:81"
        Log.d(TAG, "Menghubungkan ke WebSocket latar belakang: $wsUrl")

        val request = Request.Builder().url(wsUrl).build()
        webSocket = okHttpClient?.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket lokal terhubung di latar belakang!")
                lastWsMessageTime = System.currentTimeMillis()
                // Do not register this second socket as the head unit. The
                // Flutter UI owns pairing responses; claiming that role here
                // would replace its client number on the ESP32 Master.
                // Roster broadcasts are delivered to every connected socket.
                webSocket.send("roster")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                lastWsMessageTime = System.currentTimeMillis()
                parseIncomingMessage(text)
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "Koneksi WebSocket latar belakang gagal: ${t.message}")
                scheduleReconnect(4000)
            }
        })
    }

    private fun startWatchdog() {
        watchdogRunnable = object : Runnable {
            override fun run() {
                val silenceMs = System.currentTimeMillis() - lastWsMessageTime
                if (webSocket != null && silenceMs > 12000L) {
                    Log.w(TAG, "Watchdog: WebSocket latar belakang tidak menerima pesan selama ${silenceMs}ms. Menyambung ulang...")
                    scheduleReconnect(0)
                }
                mainHandler.postDelayed(this, 5000L)
            }
        }
        mainHandler.postDelayed(watchdogRunnable!!, 5000L)
    }

    private fun disconnectWebSocket() {
        try {
            webSocket?.cancel()
        } catch (e: Exception) {}
        webSocket = null
    }

    private fun scheduleReconnect(delayMs: Long) {
        reconnectRunnable?.let { mainHandler.removeCallbacks(it) }
        reconnectRunnable = Runnable {
            connectWebSocket()
        }
        mainHandler.postDelayed(reconnectRunnable!!, delayMs)
    }

    private fun parseIncomingMessage(message: String) {
        try {
            val trimmed = message.trim()
            if (trimmed.startsWith("[")) {
                val arr = JSONArray(trimmed)
                val callingSeats = linkedSetOf<String>()
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val calling = obj.optBoolean("calling", false) || obj.optBoolean("callPending", false)
                    if (calling) {
                        val id = obj.optString("id", "")
                        if (id.isNotEmpty()) callingSeats.add(id)
                    }
                }
                // Array roster adalah snapshot lengkap, termasuk saat kosong.
                replaceEmergencyCalls(callingSeats)
            } else if (trimmed.startsWith("{")) {
                val obj = JSONObject(trimmed)
                if (obj.has("status") && obj.getString("status") == "inverter") {
                    return
                }

                if (obj.has("seats")) {
                    val seatsObj = obj.getJSONObject("seats")
                    val callingSeats = linkedSetOf<String>()
                    val keys = seatsObj.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        val seatVal = seatsObj.opt(key)
                        if (seatVal is JSONObject) {
                            if (seatVal.optBoolean("calling", false) || seatVal.optBoolean("callPending", false)) {
                                callingSeats.add(key)
                            }
                        }
                    }
                    replaceEmergencyCalls(callingSeats)
                } else if (
                    (obj.has("seatId") || obj.has("id")) &&
                    (obj.has("calling") || obj.has("callPending"))
                ) {
                    val id = obj.optString("seatId", obj.optString("id", ""))
                    if (id.isNotEmpty()) {
                        val calling = obj.optBoolean("calling", false) ||
                            obj.optBoolean("callPending", false)
                        if (calling) {
                            addEmergencyCalls(listOf(id))
                        } else {
                            clearEmergencyCalls(listOf(id))
                        }
                    }
                } else {
                    val callingSeats = linkedSetOf<String>()
                    var containsSeatState = false
                    val keys = obj.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        val seatVal = obj.opt(key)
                        if (seatVal is JSONObject &&
                            (seatVal.has("calling") || seatVal.has("callPending"))) {
                            containsSeatState = true
                            if (seatVal.optBoolean("calling", false) || seatVal.optBoolean("callPending", false)) {
                                callingSeats.add(key)
                            }
                        }
                    }
                    if (containsSeatState) {
                        replaceEmergencyCalls(callingSeats)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Gagal mengurai JSON di latar belakang: ${e.message}")
        }
    }
}
