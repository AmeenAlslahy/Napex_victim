package com.napex.napex_victim_app.config

/**
 * إعدادات التطبيقات المُراقَبة — يجب أن تطابق AppSource في Dart
 */
object AppConfigs {

    private val monitored = mapOf(
        "sms" to "الرسائل النصية",
        "com.whatsapp" to "واتساب",
        "com.whatsapp.w4b" to "واتساب بزنس",
        "org.telegram.messenger" to "تيليجرام",
        "org.thunderdog.challegram" to "تيليجرام X",
        "com.facebook.orca" to "ماسنجر",
        "com.facebook.katana" to "فيسبوك",
        "com.instagram.android" to "إنستجرام",
        "com.viber.voip" to "فايبر",
        "com.imo.android.imoim" to "IMO",
        "org.thoughtcrime.securesms" to "سيجنال",
        "com.snapchat.android" to "سناب شات",
        "com.zhiliaoapp.musically" to "تيك توك",
        "com.twitter.android" to "تويتر X",
        "jp.naver.line.android" to "لاين",
        "com.tencent.mm" to "ويتشات",
    )

    fun isMonitored(packageName: String): Boolean = monitored.containsKey(packageName)

    fun displayName(packageName: String): String =
        monitored[packageName] ?: "غير معروف"

    fun monitoredPackageNames(): List<String> = monitored.keys.toList()
}
