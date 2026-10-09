package com.napex.napex_victim_app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

import com.napex.napex_victim_app.services.CollectorForegroundService

/**
 * إعادة تشغيل خدمة الحماية بعد إقلاع الجهاز —
 * فقط إذا كانت الحماية مفعّلة من المستخدم (يُقرأ من إعدادات Flutter).
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return

        if (!isProtectionEnabled(context)) return

        val service = Intent(context, CollectorForegroundService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(service)
            } else {
                context.startService(service)
            }
        } catch (_: Exception) {
            // على بعض الأجهزة يُمنع بدء خدمة أمامية من الخلفية —
            // ستُبدأ تلقائياً عند فتح التطبيق
        }
    }

    /// يقرأ العلم الذي يكتبه Dart عند بدء/إيقاف الحماية
    /// (SharedPreferences يتخزن بمفتاح "flutter.protection_active")
    /// افتراضياً لا نبدأ الخدمة بعد الإقلاع إلا إذا فعّل المستخدم الحماية صراحة
    private fun isProtectionEnabled(context: Context): Boolean {
        return try {
            val prefs = context.getSharedPreferences("Flutter", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.protection_active", false)
        } catch (_: Exception) {
            false
        }
    }
}
