package com.napex.napex_victim_app.ml

import android.content.Context
import android.graphics.Bitmap
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

import org.tensorflow.lite.Interpreter

/** نتيجة تصنيف إطار — sfw/nsfw بين 0 و1 */
class NsfwClassification(val sfw: Float, val nsfw: Float) {
    val isNsfw: Boolean
        get() = nsfw >= DEFAULT_THRESHOLD

    companion object {
        /** عتبة الحجب — open_nsfw: فوق 0.7 يكاد يكون محتوًى صريحًا */
        const val DEFAULT_THRESHOLD = 0.70f
    }
}

/**
 * كاشف المحتوى الإباحي — يستدعى من حرس الوسائط في NapexAccessibilityService.
 *
 * **خصوصية صارمة:** النموذج يعمل على الجهاز 100% — الصورة تُصنَّف في الذاكرة
 * وتُهمل فورًا، لا تُخزَّن ولا تُرسل لأي خادم إطلاقًا.
 *
 * النموذج: open_nsfw محوَّل إلى TFLite (ml_models/nsfw.tflite)
 *  - الدخل:  [1, 224, 224, 3] float32 — BGR مع إزاحة المتوسط (B-104, G-117, R-123)
 *  - الخرج:  [1, 2] float32 — [sfw, nsfw]
 */
class NsfwClassifier(context: Context) {

    companion object {
        const val MODEL_ASSET = "ml_models/nsfw.tflite"
        const val INPUT_SIZE = 224

        @Volatile
        var nsfwThreshold: Float = NsfwClassification.DEFAULT_THRESHOLD
    }

    private val interpreter: Interpreter?

    init {
        interpreter = try {
            val fd = context.assets.openFd(MODEL_ASSET)
            FileInputStream(fd.fileDescriptor).use { fis ->
                val model = fis.channel.map(
                    FileChannel.MapMode.READ_ONLY,
                    fd.startOffset,
                    fd.declaredLength,
                )
                Interpreter(model, Interpreter.Options().apply { numThreads = 2 })
            }
        } catch (_: Exception) {
            // النموذج غير مضمّن أو تالف — الحرس يتعطل بهدوء بدل الأعطال
            null
        }
    }

    val isAvailable: Boolean
        get() = interpreter != null

    /** تصنيف إطار — null عند فشل النموذج (لا يُعطّل الحرس) */
    fun classify(source: Bitmap): NsfwClassification? {
        val tflite = interpreter ?: return null

        // لقطات النظام تأتي بتهيئة HARDWARE — getPixels لا يعمل عليها
        val prepared: Bitmap = if (source.config == Bitmap.Config.ARGB_8888 &&
            source.width == INPUT_SIZE && source.height == INPUT_SIZE
        ) {
            source
        } else {
            val clean = if (source.config == Bitmap.Config.ARGB_8888) {
                source
            } else {
                source.copy(Bitmap.Config.ARGB_8888, false) ?: return null
            }
            Bitmap.createScaledBitmap(clean, INPUT_SIZE, INPUT_SIZE, true)
        }

        val pixels = IntArray(INPUT_SIZE * INPUT_SIZE)
        prepared.getPixels(pixels, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)

        val buffer = ByteBuffer
            .allocateDirect(INPUT_SIZE * INPUT_SIZE * 3 * 4)
            .order(ByteOrder.LITTLE_ENDIAN)
        for (px in pixels) {
            val r = (px shr 16 and 0xFF) - 123
            val g = (px shr 8 and 0xFF) - 117
            val b = (px and 0xFF) - 104
            buffer.putFloat(b.toFloat())
            buffer.putFloat(g.toFloat())
            buffer.putFloat(r.toFloat())
        }
        buffer.rewind()

        val output = Array(1) { FloatArray(2) }
        return try {
            tflite.run(buffer, output)
            NsfwClassification(output[0][0], output[0][1])
        } catch (_: Exception) {
            null
        }
    }

    fun close() {
        try {
            interpreter?.close()
        } catch (_: Exception) {
        }
    }
}
