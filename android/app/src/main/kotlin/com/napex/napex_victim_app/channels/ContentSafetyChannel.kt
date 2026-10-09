package com.napex.napex_victim_app.channels

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import com.napex.napex_victim_app.data.DnsBlocklist
import com.napex.napex_victim_app.services.NapexAccessibilityService
import com.napex.napex_victim_app.services.ContentFilterVpnService

/** قناة حماية المحتوى: فلترة DNS (VPN) + حرس NSFW */
class ContentSafetyChannel(
    private val context: Context,
    private val messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.napex.victim/content_safety"
        const val NSFW_STREAM = "com.napex.victim/nsfw_stream"

        private const val VPN_REQUEST_CODE = 2001
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null

    // الحالة الأخيرة: هل الـ guard مفعّل من Dart؟
    @Volatile
    var guardEnabled: Boolean = false

    fun register() {
        methodChannel.setMethodCallHandler(this)
        EventChannel(messenger, NSFW_STREAM).setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadBlocklist" -> {
                // تحليل ~77 ألف نطاق — خارج الخيط الرئيسي ثم إرجاع النتيجة للرئيسي
                val appContext = context.applicationContext
                DnsBlocklist.load(appContext) { size ->
                    Handler(Looper.getMainLooper()).post { result.success(size) }
                }
            }
            "isNsfwModelAvailable" -> {
                val appContext = context.applicationContext
                Thread {
                    val available = NapexAccessibilityService
                        .ensureClassifier(appContext)?.isAvailable ?: false
                    Handler(Looper.getMainLooper()).post { result.success(available) }
                }.start()
            }
            "startWebFilter" -> {
                val intent = Intent(context, ContentFilterVpnService::class.java)
                intent.action = ContentFilterVpnService.ACTION_START
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(true)
            }
            "stopWebFilter" -> {
                val intent = Intent(context, ContentFilterVpnService::class.java)
                intent.action = ContentFilterVpnService.ACTION_STOP
                context.startService(intent)
                result.success(true)
            }
            "isWebFilterRunning" -> result.success(ContentFilterVpnService.isRunning)
            // موافقة نظام الـ VPN — تفتح حوار النظام ثم يعيد MainActivity التشغيل
            "prepareVpn" -> {
                val intent = VpnService.prepare(context)
                if (intent != null) {
                    if (context is android.app.Activity) {
                        context.startActivityForResult(intent, VPN_REQUEST_CODE)
                        result.success("consent_needed")
                    } else {
                        result.success("consent_needed")
                    }
                } else {
                    result.success("granted")
                }
            }
            "openOverlaySettings" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    android.net.Uri.parse("package:${context.packageName}"),
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(true)
            }
            "showNsfwOverlay" -> {
                com.napex.napex_victim_app.ui.NsfwOverlay.show(context)
                result.success(true)
            }
            "canDrawOverlays" -> {
                val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    android.provider.Settings.canDrawOverlays(context)
                } else {
                    true
                }
                result.success(can)
            }
            // فحص ذاتي: القائمة محمّلة؟ النطاق المحجوب يُحجب والمسموح يُمرر؟
            "selfTestWebFilter" -> {
                val appContext = context.applicationContext
                DnsBlocklist.load(appContext) { size ->
                    val blockedOk = DnsBlocklist.isBlocked("pornhub.com")
                    val allowedOk = !DnsBlocklist.isBlocked("example.com")
                    Handler(Looper.getMainLooper()).post {
                        result.success(
                            mapOf(
                                "size" to size,
                                "blockedOk" to blockedOk,
                                "allowedOk" to allowedOk,
                            ),
                        )
                    }
                }
            }
            // فحص ذاتي: النموذج يعمل؟ (صورة محايدة → يجب أن يكون nsfw منخفضاً)
            "selfTestNsfw" -> {
                val appContext = context.applicationContext
                Thread {
                    val classifier = NapexAccessibilityService.ensureClassifier(appContext)
                    val out: Map<String, Any?> = if (classifier == null) {
                        mapOf("available" to false)
                    } else {
                        val bmp = android.graphics.Bitmap.createBitmap(
                            224, 224, android.graphics.Bitmap.Config.ARGB_8888,
                        )
                        bmp.eraseColor(0xFF808080.toInt())
                        val r = classifier.classify(bmp)
                        mapOf(
                            "available" to true,
                            "sfw" to r?.sfw,
                            "nsfw" to r?.nsfw,
                        )
                    }
                    Handler(Looper.getMainLooper()).post { result.success(out) }
                }.start()
            }
            "setUrlFilterEnabled" -> {
                NapexAccessibilityService.urlFilterEnabled =
                    call.argument<Boolean>("enabled") ?: true
                result.success(true)
            }
            "setGuardEnabled" -> {
                guardEnabled = call.argument<Boolean>("enabled") ?: false
                // العلم الذي يفحصه الحرس فعلياً هو علم الخدمة — تتم مزامنته هنا
                NapexAccessibilityService.guardEnabled = guardEnabled
                if (guardEnabled) {
                    val appContext = context.applicationContext
                    Thread { NapexAccessibilityService.ensureClassifier(appContext) }.start()
                }
                result.success(true)
            }
            "stopMediaCapture" -> {
                NapexAccessibilityService.stopGuardCapture()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // ============ EventChannel: لقطات حرس الوسائط ============

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        com.napex.napex_victim_app.services.NapexAccessibilityService
            .attachNsfwSink(events)
    }

    override fun onCancel(arguments: Any?) {
        com.napex.napex_victim_app.services.NapexAccessibilityService
            .detachNsfwSink()
    }
}
