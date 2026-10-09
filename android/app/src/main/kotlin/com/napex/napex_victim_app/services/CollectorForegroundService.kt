package com.napex.napex_victim_app.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * خدمة أمامية تُبقي عملية الحماية حية
 * (عرض إشعار دائم يوضح للمستخدم أن الحماية نشطة).
 */
class CollectorForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "napex_collector_service"
        const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundCompat()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "خدمة الحماية",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "تُبقي حماية الابتزاز نشطة في الخلفية"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("NAP-EX")
                .setContentText("الحماية من الابتزاز نشطة")
                .setSmallIcon(android.R.drawable.ic_secure)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("NAP-EX")
                .setContentText("الحماية من الابتزاز نشطة")
                .setSmallIcon(android.R.drawable.ic_secure)
                .setOngoing(true)
                .build()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
