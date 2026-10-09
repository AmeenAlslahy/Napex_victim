package com.napex.napex_victim_app.ui

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * حاجب الشاشة عند اكتشاف محتوى غير لائق (NSFW Guard).
 *
 * **دائم** — لا يختفي تلقائياً (الإخفاء التلقائي كان خطأ: المشاهدة
 * تكمل خلفه بعد 5 ثوانٍ). المستخدم يختار:
 *  - "إغلاق المشاهدة": يعيده للشاشة الرئيسية فعلياً (يغلق العرض)
 *  - "إخفاء التحذير": يخفي الحاجب فقط
 */
object NsfwOverlay {

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    fun show(context: Context): Boolean {
        if (overlayView != null) return true

        // بدون صلاحية "العرض فوق التطبيقات" لا يمكن إظهار الحاجب — فشل صامت سابقاً
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(context)
        ) {
            android.util.Log.w("NsfwOverlay", "overlay permission missing — cannot block")
            return false
        }

        windowManager =
            context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        overlayView = createOverlayView(context)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            },
            // NOT_FOCUSABLE لا يمنع النقر على الأزرار — يمنع لوحة المفاتيح فقط
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )

        return try {
            windowManager?.addView(overlayView, params)
            true
        } catch (_: Exception) {
            overlayView = null
            false
        }
    }

    /** إغلاق المشاهدة فعلياً — العودة للشاشة الرئيسية */
    private fun sendToHome(context: Context) {
        try {
            context.startActivity(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (_: Exception) {
        }
    }

    fun hide() {
        overlayView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {
            }
        }
        overlayView = null
    }

    private fun button(context: Context, text: String, bg: Int, fg: Int, onClick: () -> Unit): Button {
        return Button(context).apply {
            this.text = text
            setTextColor(fg)
            textSize = 16f
            isAllCaps = false
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                cornerRadius = 48f
                setColor(bg)
            }
            setPadding(64, 24, 64, 24)
           setOnClickListener { onClick() }
        }
    }

    private fun createOverlayView(context: Context): View {
        val pad = (16 * context.resources.displayMetrics.density).toInt()
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F2111111"))

            addView(
                TextView(context).apply {
                    text = "⛔"
                    textSize = 72f
                    gravity = Gravity.CENTER
                    setTextColor(Color.WHITE)
                }
            )
            addView(
                TextView(context).apply {
                    text = "تم اكتشاف محتوى غير لائق"
                    textSize = 24f
                    gravity = Gravity.CENTER
                    setTextColor(Color.WHITE)
                    setTypeface(typeface, Typeface.BOLD)
                    setPadding(0, 32, 0, 0)
                }
            )
            addView(
                TextView(context).apply {
                    text = "تم حجب العرض تلقائياً بواسطة NAP-EX\nالحماية تعمل على جهازك — حتى بدون إنترنت"
                    textSize = 15f
                    gravity = Gravity.CENTER
                    setTextColor(Color.parseColor("#CCCCCC"))
                    setPadding(0, 16, 0, pad * 2)
                }
            )

            val closeBtn = button(
                context,
                "إغلاق المشاهدة",
                Color.parseColor("#E53935"),
                Color.WHITE,
            ) {
                hide()
                sendToHome(context)
            }
            addView(closeBtn)

            val dismiss = TextView(context).apply {
                text = "إخفاء التحذير"
                textSize = 14f
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#9E9E9E"))
                setPadding(0, pad, 0, 0)
                setOnClickListener { hide() }
            }
            addView(dismiss)
        }
    }
}
