package com.napex.napex_victim_app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

import com.napex.napex_victim_app.services.CollectedMessage
import com.napex.napex_victim_app.services.MessageEventBus

import java.util.UUID

/**
 * مستقبل الرسائل النصية — يلتقط SMS الواردة ويرسلها للتحليل
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val sender = messages[0].originatingAddress
        if (sender.isNullOrBlank()) return

        val body = messages.joinToString("") { it.messageBody ?: "" }.trim()
        if (body.isBlank()) return

        // معرف حتمي — البث قد يُسلَّم مرتين والـ Dart يتجاهل التكرار به
        val timestamp = System.currentTimeMillis()
        val id = UUID.nameUUIDFromBytes("$sender|$timestamp|$body".toByteArray())
            .toString()

        MessageEventBus.emit(
            CollectedMessage(
                id = id,
                sender = sender,
                content = body.take(2000),
                source = "sms",
                timestamp = timestamp,
            )
        )
    }
}
