package com.napex.napex_victim_app.data

import android.content.Context
import java.util.concurrent.Executors

/**
 * قائمة حجب النطاقات — تُحمَّل من assets/blocklists/nsfw_domains.txt
 * (صيغة hosts من StevenBlack — "0.0.0.0 domain.com" — أو نطاق في كل سطر)
 *
 * المطابقة بالسلسلة الأبوية: sub.example.com تُفحص كـ
 * "sub.example.com" → "example.com" → "com" ضد HashSet — O(عدد المقاطع)
 *
 * كل المعالجة محلية 100% — لا يُرسل أي استعلام أو نطاق لأي خادم.
 */
object DnsBlocklist {

    private const val ASSET_PATH = "blocklists/nsfw_domains.txt"

    /** نطاقات تعليمية/صحية مشروعة قد تلتقطها القوائم */
    private val allowedDomains = setOf(
        "wikipedia.org",
        "who.int",
        "plannedparenthood.org",
    )

    @Volatile
    private var blockedDomains: Set<String> = emptySet()

    @Volatile
    var isLoaded: Boolean = false
        private set

    private val executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "dns-blocklist-loader").apply { isDaemon = true }
    }

    /**
     * تحميل غير متزامن (تحليل ~77 ألف نطاق لا يجوز أن يمر عبر الخيط الرئيسي).
     * onDone يُستدعى من خيط التحميل — أعد النتيجة للخيط الرئيسي بنفسك عند الحاجة.
     */
    fun load(context: Context, onDone: (Int) -> Unit = {}) {
        executor.execute {
            blockedDomains = parse(context)
            isLoaded = true
            onDone(blockedDomains.size)
        }
    }

    private fun parse(context: Context): Set<String> {
        return try {
            val hosts = mutableSetOf<String>()
            context.assets.open(ASSET_PATH).bufferedReader().useLines { lines ->
                for (raw in lines) {
                    val line = raw.trim()
                    if (line.isEmpty() || line.startsWith("#")) continue
                    // صيغة hosts: "0.0.0.0 domain" — وإلا نطاق مجرد
                    val parts = line.split(Regex("\\s+"))
                    val domain = when {
                        parts.size >= 2 &&
                            parts[0] in listOf("0.0.0.0", "127.0.0.1", "::1") -> parts[1]
                        parts.size == 1 -> parts[0]
                        else -> null
                    }?.lowercase()?.trim('.') ?: continue
                    if (domain == "localhost" || domain == "localhost.localdomain" ||
                        domain == "broadcasthost" || domain.isEmpty()
                    ) continue
                    hosts.add(domain)
                }
            }
            hosts
        } catch (_: Exception) {
            emptySet()
        }
    }

    fun isBlocked(domain: String): Boolean {
        var d = domain.lowercase().trim().trimEnd('.')
        if (d.isEmpty()) return false
        while (true) {
            if (allowedDomains.contains(d)) return false
            if (blockedDomains.contains(d)) return true
            val idx = d.indexOf('.')
            if (idx <= 0 || idx == d.length - 1) return false
            d = d.substring(idx + 1)
        }
    }

    fun size(): Int = blockedDomains.size
}
