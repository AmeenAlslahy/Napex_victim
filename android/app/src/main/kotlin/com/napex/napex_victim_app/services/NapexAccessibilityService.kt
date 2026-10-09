package com.napex.napex_victim_app.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

import com.napex.napex_victim_app.config.AppConfigs
import com.napex.napex_victim_app.data.DnsBlocklist
import com.napex.napex_victim_app.ml.NsfwClassifier
import com.napex.napex_victim_app.ui.NsfwOverlay
import com.napex.napex_victim_app.parser.NotificationParser

import io.flutter.plugin.common.EventChannel

import java.util.UUID
import java.util.concurrent.Executors

/**
 * خدمة إمكانية الوصول — مهمتان:
 * 1) كشف الابتزاز: إشعارات ومحتوى التطبيقات المُراقَبة → Flutter
 * 2) حرس الوسائط (NSFW Guard): لقطات متدرجة عند فتح المعارض/المشغلات
 *    تُبث لـ Dart لتحليلها (النموذج على جهاز المستخدم) — مع Early Exit
 */
class NapexAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "NapexA11y"

        // خنق بسيط: نفس النص داخل 3 ثوانٍ لا يُبث مرتين
        private var lastText: String = ""
        private var lastEmitAt: Long = 0L

        // ============ NSFW Guard ============
        private const val NSFW_DEBOUNCE_MS = 500L
        private const val NSFW_MAX_TOTAL_MS = 60_000L

        /** تطبيقات عرض الوسائط المُراقَبة للحرس */
        private val MEDIA_APPS = setOf(
            // معارض ومشغلات
            "com.google.android.apps.photos",
            "com.android.gallery3d",
            "com.sec.android.gallery3d",
            "com.miui.gallery",
            "com.coloros.gallery3d",
            "org.videolan.vlc",
            "com.mxtech.videoplayer.ad",
            // متصفحات (فيديو/صور داخل المتصفح أيضاً)
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.sec.android.app.sbrowser",
            "com.opera.browser",
            "com.brave.browser",
            "com.microsoft.emmx",
            "com.UCMobile.intl",
            // أجهزة Transsion (Infinix/Tecno/itel — XOS/HiOS)
            "com.transsion.gallery",
            "com.transsion.video",
            "com.transsion.photoloop",
            // OEM أخرى شائعة
            "com.oneplus.gallery",
            "com.huawei.photos",
            "com.samsung.android.gallery",
        )

        /** متصفحات فلتر الروابط — تعمل بدون VPN وبالتوازي مع أي VPN */
        private val BROWSER_APPS = setOf(
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.sec.android.app.sbrowser",
            "com.opera.browser",
            "com.brave.browser",
            "com.microsoft.emmx",
            "com.UCMobile.intl",
            "com.transsion.browser",
        )

        @Volatile
        var guardEnabled: Boolean = false

        /**
         * فلتر روابط المتصفح — يعمل عبر إمكانية الوصول بدون VPN
         * (متوافق مع أي VPN يستخدمه المستخدم — لا يحتاج صلاحية VPN)
         */
        @Volatile
        var urlFilterEnabled: Boolean = true

        @Volatile
        var stopMediaCapture: Boolean = false

        @Volatile
        private var nsfwSink: EventChannel.EventSink? = null

        fun attachNsfwSink(sink: EventChannel.EventSink?) {
            nsfwSink = sink
        }

        fun detachNsfwSink() {
            nsfwSink = null
        }

        /** مصنّف NSFW — يُهيأ مرة واحدة على خيط التنفيذ (النموذج محلي على الجهاز) */
        private var classifier: NsfwClassifier? = null

        fun ensureClassifier(appContext: android.content.Context): NsfwClassifier? {
            synchronized(this) {
                if (classifier == null) {
                    classifier = NsfwClassifier(appContext)
                }
                return classifier?.takeIf { it.isAvailable }
            }
        }

        fun closeClassifier() {
            synchronized(this) {
                classifier?.close()
                classifier = null
            }
        }

        /** بث نتيجة حجب إلى Dart (نتيجة فقط — لا صور إطلاقاً) */
        fun emitNsfwBlocked(score: Float) {
            val sink = nsfwSink ?: return
            Handler(Looper.getMainLooper()).post {
                sink.success(
                    mapOf(
                        "type" to "nsfw_blocked",
                        "score" to score,
                        "at" to System.currentTimeMillis(),
                    ),
                )
            }
        }

        fun stopGuardCapture() {
            stopMediaCapture = true
        }
    }

    private val screenshotExecutor = Executors.newSingleThreadExecutor()
    private val guardHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var guardActive = false

    // خنق فحص روابط المتصفح + تذكّر آخر نطاق محجوب (تفادي تكرار الحاجب)
    private var lastUrlScanAt = 0L
    private var lastBlockedDomain: String? = null
    private var lastBlockedAt = 0L


    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return

        // فلتر روابط المتصفح — فحص أولوي مستقل عن مسار كشف الابتزاز
        if (packageName in BROWSER_APPS &&
            (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)
        ) {
            handleBrowserEvent(event.text)
            return
        }

        when (event.eventType) {
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                if (!AppConfigs.isMonitored(packageName)) return
                val notification = event.parcelableData as? Notification ?: return
                val parsed =
                    NotificationParser.parseNotification(notification, packageName)
                        ?: return
                MessageEventBus.emit(parsed)
            }

            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                if (!AppConfigs.isMonitored(packageName)) return

                // خصوصية: تجاهل أحداث حقول الإدخال (كلمات المرور، البطاقات، البحث)
                val className = event.className?.toString() ?: ""
                if (className.endsWith("EditText") ||
                    className.endsWith("AutoCompleteTextView") ||
                    className.endsWith("SearchView")
                ) {
                    return
                }

                val textList = event.text ?: return
                if (textList.isEmpty()) return

                val text = textList.joinToString(" ").trim()
                if (text.isBlank() || text.length < 5) return

                val now = System.currentTimeMillis()
                if (text == lastText && now - lastEmitAt < 3000) return
                lastText = text
                lastEmitAt = now

                MessageEventBus.emit(
                    CollectedMessage(
                        id = UUID.randomUUID().toString(),
                        sender = AppConfigs.displayName(packageName),
                        content = text.take(1000),
                        source = packageName,
                        timestamp = now,
                    )
                )
            }

            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                if (!guardEnabled) return
                if (!MEDIA_APPS.contains(packageName)) return
                val now = System.currentTimeMillis()
                if (now - lastEmitAt < NSFW_DEBOUNCE_MS) return
                lastEmitAt = now
                startGuardLoop()
            }
        }
    }

    /** عينة متدرجة: فوري → 1s → 5s → 10s → كل 10s (أقصى 60 ثانية) + Early Exit */
    private fun startGuardLoop() {
        if (guardActive) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return

        guardActive = true
        stopMediaCapture = false

        Log.i(TAG, "NSFW guard triggered")
        // تهيئة النموذج خارج الخيط الرئيسي (أول لقطة قد تسبق جهوزيته — تتخطى بأمان)
        screenshotExecutor.execute { ensureClassifier(applicationContext) }

        val intervals = longArrayOf(
            0, 500, 1000, 1500, 2000, 3000, 4000,
            5000, 5000, 5000, 5000, 5000, 5000, 5000,
        )
        var elapsed = 0L

        for (delay in intervals) {
            guardHandler.postDelayed({
                if (!guardActive || stopMediaCapture || !guardEnabled) {
                    guardActive = false
                    return@postDelayed
                }
                takeScreenshotSafe()
            }, elapsed)
            elapsed += delay
        }

        guardHandler.postDelayed({
            guardActive = false
        }, NSFW_MAX_TOTAL_MS)
    }

    private fun takeScreenshotSafe() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        try {
            takeScreenshot(
                android.view.Display.DEFAULT_DISPLAY,
                screenshotExecutor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        val bitmap = Bitmap.wrapHardwareBuffer(
                            screenshot.hardwareBuffer,
                            screenshot.colorSpace,
                        )
                        screenshot.hardwareBuffer.close()
                        bitmap?.let { bmp ->
                            // التصنيف هنا على خيط التنفيذ — الصورة تُهمل فور الفحص
                            val result = classifier?.classify(bmp)
                            if (result != null && result.nsfw >= NsfwClassifier.nsfwThreshold) {
                                guardHandler.post {
                                    NsfwOverlay.show(applicationContext)
                                }
                                stopMediaCapture = true
                                emitNsfwBlocked(result.nsfw)
                            }
                        }
                    }

                    override fun onFailure(errorCode: Int) {
                        // لقطات غير متاحة — تجاهل بهدوء
                    }
                },
            )
        } catch (_: Exception) {
        }
    }

    // ============ فلتر روابط المتصفح (بدون VPN) ============

    /** استخراج النطاق من نص يشبه الرابط — null إن لم يكن رابطاً */
    private fun extractHost(raw: String): String? {
        var t = raw.trim()
        if (t.isEmpty() || !t.contains('.')) return null
        // قد يأتي "نص عنوان طويل" — خذ المقطع الذي يحوي نقطة
        if (t.contains(' ')) {
            t = t.split(' ').firstOrNull { it.contains('.') } ?: return null
        }
        t = t.removePrefix("http://").removePrefix("https://")
            .removePrefix("www.").trimStart('.')
        val host = t.substringBefore('/').substringBefore('?').substringBefore(':')
            .lowercase().trimEnd('.')
        return if (host.length > 3 && host.contains('.')) host else null
    }

    /** فحص نصوص نافذة المتصفح — عند مطابقة نطاق محجوب: حاجب فوري */
    private fun handleBrowserEvent(textList: List<CharSequence>?) {
        if (!urlFilterEnabled) return
        val texts = textList ?: return
        val now = System.currentTimeMillis()
        if (now - lastUrlScanAt < 250) return // خنق: لا فحص كل حدث
        lastUrlScanAt = now

        for (t in texts) {
            val host = extractHost(t?.toString() ?: continue) ?: continue
            // نفس النطاق المحجوب حديثاً — لا تكرار للحاجب
            if (host == lastBlockedDomain && now - lastBlockedAt < 10_000) continue
            if (DnsBlocklist.isBlocked(host)) {
                lastBlockedDomain = host
                lastBlockedAt = now
                Log.i(TAG, "URL blocked: $host")
                guardHandler.post {
                    NsfwOverlay.show(applicationContext)
                }
                return
            }
        }
    }

    override fun onInterrupt() {
        // لا شيء مطلوب
    }

    override fun onDestroy() {
        guardActive = false
        guardHandler.removeCallbacksAndMessages(null)
        screenshotExecutor.shutdown()
        closeClassifier()
        super.onDestroy()
    }
}
