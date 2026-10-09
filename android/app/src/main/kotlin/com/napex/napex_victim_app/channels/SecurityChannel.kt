package com.napex.napex_victim_app.channels

import android.content.Context
import android.os.Build
import android.os.Debug
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import java.io.File

/**
 * قناة الأمان — فحص حالة الجهاز (Root / محاكي / Debugger) والتوقيع
 */
class SecurityChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.napex.victim/security"

        private val ROOT_INDICATORS = listOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/system/sd/xbin/su",
            "/system/app/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
        )
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    fun register() {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDeviceRooted" -> result.success(isDeviceRooted())
            "isEmulator" -> result.success(isEmulator())
            "isDebuggerAttached" -> result.success(Debug.isDebuggerConnected())
            // التحقق الفعلي من بصمة الشهادة يُفعَّل في مرحلة الإنتاج
            "verifySignature" -> result.success(true)
            "getSignatureHash" -> result.success("")
            else -> result.notImplemented()
        }
    }

    private fun isDeviceRooted(): Boolean {
        if (Build.TAGS?.contains("test-keys") == true) return true
        return ROOT_INDICATORS.any { File(it).exists() }
    }

    private fun isEmulator(): Boolean =
        Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.contains("emulator") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            Build.PRODUCT.contains("sdk")
}
