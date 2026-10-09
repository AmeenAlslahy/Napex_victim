package com.napex.napex_victim_app.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import kotlin.concurrent.thread

import com.napex.napex_victim_app.data.DnsBlocklist

/**
 * حماية الويب — فلترة DNS عبر VPN محلي
 *
 * النمط: يصبح التطبيق خادم DNS للجهاز (10.111.0.1) — يفحص كل استعلام،
 * المحظور يُرد عليه بـ 0.0.0.0 والمسموح يُحوَّل لخادم DNS حقيقي.
 *
 * حد معروف وموثق: يغطي DNS (UDP/53) — الاستعلامات المشفرة (DoH) أو
 * المدمجة في التطبيق تتجاوزه (نفس سقف Norton/Qustodio ~90-95%).
 */
class ContentFilterVpnService : VpnService() {

    companion object {
        private const val TAG = "ContentFilterVpn"
        private const val CHANNEL_ID = "napex_content_filter"
        private const val NOTIFICATION_ID = 1002

        /** إشعار تحذير عند إزاحة الفلتر بـ VPN آخر — أهمية أعلى ليُرى */
        private const val ALERT_CHANNEL_ID = "napex_content_filter_alerts"
        private const val ALERT_NOTIFICATION_ID = 1003

        private const val VPN_ADDRESS = "10.111.0.2"
        private const val VPN_DNS = "10.111.0.1"
        private const val REAL_DNS = "8.8.8.8"
        private const val MAX_PACKET = 32767

        const val ACTION_START = "com.napex.napex_victim_app.VPN_START"
        const val ACTION_STOP = "com.napex.napex_victim_app.VPN_STOP"

        /** خوادم DNS العامة الشائعة — تُحجب كمسارات لتقفيل تجاوز DoH */
        private val DOH_PROVIDER_IPS = listOf(
            "8.8.8.8", "8.8.4.4",          // Google
            "1.1.1.1", "1.0.0.1",          // Cloudflare
            "9.9.9.9", "149.112.112.112",  // Quad9
            "94.140.14.14", "94.140.15.15", // AdGuard
            "208.67.222.222", "208.67.220.220", // OpenDNS
        )

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var worker: Thread? = null

    /**
     * خوادم DNS الحقيقية للجهاز (تُلتقط قبل رفع النفق).
     * حاسم في اليمن: مزودو الإنترنت يحجبون/يعيقون DNS الأجنبي (8.8.8.8/1.1.1.1)
     * — خادم مزودك المحلي هو الوحيد المضمون الرد.
     */
    @Volatile
    private var upstreamServers: List<java.net.InetAddress> = listOf(
        java.net.InetAddress.getByName("8.8.8.8"),
        java.net.InetAddress.getByName("1.1.1.1"),
    )

    /** بركة التحويل — 4 خيوط كافية لمعدل DNS الطبيعي (استعلامات/ثانية قليلة) */
    private val upstreamExecutor = java.util.concurrent.Executors.newFixedThreadPool(4) { r ->
        Thread(r, "dns-upstream").apply { isDaemon = true }
    }
    @Volatile
    private var stopping = false

    override fun onCreate() {
        super.onCreate()
        DnsBlocklist.load(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundCompat()
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startVpn()
        return START_STICKY
    }

    private fun startVpn() {
        if (vpnInterface != null) return
        try {
            val builder = Builder()
                .setSession("NAP-EX Content Filter")
                .setMtu(1500)
                .addAddress(VPN_ADDRESS, 32)
                .addDnsServer(VPN_DNS)
                // مسار خادم DNS الوهمي فقط — بقية الترافيك طبيعي
                // (حجب مسارات خوادم DNS العامة أُزيل: كان يقتل Private DNS
                // فيعطل إنترنت الجهاز كله — فلترة DoH تُدار بمستوى أذكى لاحقاً)

            // التقاط DNS الجهاز الحقيقي قبل أن يصبح النفق هو الشبكة الافتراضية
            try {
                val cms = getSystemService(android.content.Context.CONNECTIVITY_SERVICE)
                    as android.net.ConnectivityManager
                val props = cms.getLinkProperties(cms.activeNetwork)
                val deviceDns = props?.dnsServers
                    ?.filter { it is java.net.Inet4Address }
                    ?.map { it as java.net.InetAddress }
                    .orEmpty()
                if (deviceDns.isNotEmpty()) {
                    upstreamServers = deviceDns.take(2)
                    Log.i(TAG, "upstream DNS = $deviceDns")
                }
            } catch (_: Exception) {
                // إبقاء 8.8.8.8/1.1.1.1 كاحتياط
            }

            vpnInterface = builder.establish()
            stopping = false

            worker = thread(name = "napex-dns-filter") {
                processPackets()
            }
            Log.i(TAG, "DNS filter VPN started (${DnsBlocklist.size()} domains)")
        } catch (e: Exception) {
            Log.e(TAG, "VPN start failed", e)
        }
    }

    /**
     * أندرويد يسمح بشبكة خاصة واحدة — عندما يتولى تطبيق VPN آخر الاتصال
     * (أو المستخدم سحب الإذن) يستدعي النظام onRevoke. بدون هذا المعالج كان
     * الفلتر يتوقف بصمت بينما الإشعار الدائم يوهم بأن الحماية نشطة.
     */
    override fun onRevoke() {
        Log.w(TAG, "VPN revoked — another VPN took over or permission withdrawn")
        isRunning = false
        stopping = true
        try {
            worker?.interrupt()
            vpnInterface?.close()
        } catch (_: Exception) {
        }
        vpnInterface = null
        worker = null

        postDisplacedAlert()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /** تنبيه صريح: المستخدم غير محمي الآن — لا يجوز أن يبقى بلا علم */
    private fun postDisplacedAlert() {
        try {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        ALERT_CHANNEL_ID,
                        "تنبيهات توقف الحماية",
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ).apply {
                        description = "ينبهك عند توقف فلتر المحتوى (مثلاً بسبب VPN آخر)"
                        setShowBadge(true)
                    },
                )
            }

            // النقر يفتح التطبيق لإعادة التفعيل
            val openApp = PendingIntent.getActivity(
                this,
                0,
                Intent(this, Class.forName("com.napex.napex_victim_app.MainActivity"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE,
            )

            val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, ALERT_CHANNEL_ID)
                    .setContentTitle("توقف فلتر المحتوى")
                    .setContentText(
                        "تطبيق VPN آخر تولى الاتصال — الفلتر متوقف الآن. " +
                            "اضغط لإعادة تفعيل الحماية من NAP-EX",
                    )
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setAutoCancel(true)
                    .setContentIntent(openApp)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
                    .setContentTitle("توقف فلتر المحتوى")
                    .setContentText("تطبيق VPN آخر تولى الاتصال — أعد التفعيل من NAP-EX")
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setAutoCancel(true)
                    .setContentIntent(openApp)
                    .build()
            }
            manager.notify(ALERT_NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "failed to post displaced-filter alert", e)
        }
    }

    /** حلقة معالجة الحزم: DNS فقط — الاستعلام يُجاب محلياً أو يُحوَّل */
    /**
     * حلقة معالجة الحزم — قراءة TUN فقط.
     * التحويل غير متزامن عبر بركة خيوط: بدونه كان انتظار رد الخادم الأعلى
     * (حتى 5 ثوانٍ) يسدّ الحلقة الواحدة فيتباطأ إنترنت الجهاز كله أثناء
     * عمل الفلتر — هذا كان سبب "إضعاف الشبكة".
     */
    private fun processPackets() {
        val vpn = vpnInterface ?: return
        val input = FileInputStream(vpn.fileDescriptor)
        val output = FileOutputStream(vpn.fileDescriptor)
        val packet = ByteArray(MAX_PACKET)

        while (!stopping) {
            try {
                val length = input.read(packet)
                if (length <= 20) continue

                val buffer = ByteBuffer.wrap(packet, 0, length)

                if (!isDnsQuery(buffer, length)) {
                    continue // غير DNS → تجاهل (لا نوجه ترافيك آخر)
                }

                val domain = extractDomain(buffer) ?: continue
                val sourceIp = ByteArray(4).also {
                    System.arraycopy(packet, 12, it, 0, 4)
                }
                val sourcePort = ((packet[20].toInt() and 0xFF) shl 8) or
                    (packet[21].toInt() and 0xFF)

                if (DnsBlocklist.isBlocked(domain)) {
                    // المسار السريع: الحجب محلي فوري — بلا أي انتظار شبكة
                    Log.d(TAG, "Blocked: $domain")
                    val response = buildBlockedResponse(packet, length)
                    synchronized(output) {
                        output.write(response)
                        output.flush()
                    }
                } else {
                    val dnsPayloadLength = length - 28
                    if (dnsPayloadLength <= 0) continue
                    val dnsPayload = ByteArray(dnsPayloadLength)
                    System.arraycopy(packet, 28, dnsPayload, 0, dnsPayloadLength)
                    val srcIp = sourceIp
                    val srcPort = sourcePort
                    upstreamExecutor.execute {
                        relayUpstream(dnsPayload, srcIp, srcPort, output)
                    }
                }
            } catch (e: java.net.SocketTimeoutException) {
                // لا نشاط على TUN — استمر بهدوء
            } catch (e: Exception) {
                if (!stopping) Log.d(TAG, "packet error", e)
            }
        }
    }

    /**
     * تحويل استعلام DNS لخادمين حقيقيين (Google + Cloudflare) بالتوازي —
     * أول رد يفوز: زمن استجابة أدنى ومرونة عند تعطل أحدهما.
     * يعمل على خيط البركة — لا يؤثر على حلقة القراءة أبداً.
     */
    private fun relayUpstream(
        dnsPayload: ByteArray,
        clientIp: ByteArray,
        clientPort: Int,
        output: FileOutputStream,
    ) {
        try {
            DatagramSocket().use { socket ->
                // حاسم: بدونه تُوجَّه حزم التحويل إلى جدول النفق فتسقط
                protect(socket)
                socket.soTimeout = 3000

                // خوادم مزود الجهاز المحلي — سباق أول رد يفوز
                val servers = upstreamServers
                for (srv in servers) {
                    socket.send(DatagramPacket(dnsPayload, dnsPayload.size, srv, 53))
                }
                if (servers.isEmpty()) {
                    socket.send(DatagramPacket(
                        dnsPayload, dnsPayload.size,
                        InetAddress.getByName("8.8.8.8"), 53,
                    ))
                }

                val reply = ByteArray(MAX_PACKET)
                val replyPacket = DatagramPacket(reply, reply.size)
                socket.receive(replyPacket)

                val out = buildReplyPacket(
                    reply, replyPacket.length, clientIp, clientPort,
                )
                synchronized(output) {
                    output.write(out)
                    output.flush()
                }
            }
        } catch (_: Exception) {
            // تعذر الخادمان — العميل يعيد المحاولة تلقائياً بعد مهلته
        }
    }

    // ============ تحليل الحزم ============

    private fun isDnsQuery(buffer: ByteBuffer, length: Int): Boolean {
        if (length < 34) return false
        val versionIhl = buffer.get(0).toInt() and 0xFF
        if ((versionIhl shr 4) != 4) return false
        val protocol = buffer.get(9).toInt() and 0xFF
        if (protocol != 17) return false // UDP
        val dstPort = ((buffer.get(22).toInt() and 0xFF) shl 8) or
            (buffer.get(23).toInt() and 0xFF)
        return dstPort == 53
    }

    /** استخراج اسم النطاق من أول سؤال في رسالة DNS */
    private fun extractDomain(buffer: ByteBuffer): String? {
        return try {
            val sb = StringBuilder()
            var i = 28 // IP(20) + UDP(8)
            var jumps = 0
            while (jumps < 10) {
                val len = buffer.get(i).toInt() and 0xFF
                if (len == 0) break
                if ((len and 0xC0) != 0) break // ضغط المؤشر — نتجاهله
                for (j in 0 until len) {
                    sb.append((buffer.get(i + 1 + j).toInt().and(0xFF)).toChar())
                }
                sb.append('.')
                i += len + 1
                jumps++
            }
            if (sb.isEmpty()) null else sb.toString().trimEnd('.')
        } catch (_: Exception) {
            null
        }
    }

    /** رد DNS محلي: النطاق المحجوب → 0.0.0.0 */
    private fun buildBlockedResponse(query: ByteArray, length: Int): ByteArray {
        val response = query.copyOf(length)
        response[2] = (response[2].toInt() or 0x80).toByte() // QR = 1
        response[3] = 0 // flags: رد عادي
        response[6] = 0; response[7] = 1 // ANCOUNT = 1
        response[8] = 0; response[9] = 0 // NSCOUNT = 0
        response[10] = 0; response[11] = 0 // ARCOUNT = 0

        val answer = byteArrayOf(
            0xC0.toByte(), 0x0C, // pointer للاسم في السؤال
            0, 1,                // TYPE = A
            0, 1,                // CLASS = IN
            0, 0, 0, 60,         // TTL = 60
            0, 4,                // RDLENGTH = 4
            0, 0, 0, 0           // RDATA = 0.0.0.0
        )

        val out = response + answer
        fixUdpLength(out) // UDP length += 16 (الجواب المضاف)
        fixIpv4TotalLength(out)
        fixIpv4Checksum(out)
        return out
    }

    /** تمرير رد خادم DNS الحقيقي — بتبديل العناوين والمنافذ */
    private fun buildReplyPacket(
        dnsPayload: ByteArray,
        dnsLength: Int,
        phoneIp: ByteArray,
        phonePort: Int,
    ): ByteArray {
        val total = 28 + dnsLength
        val out = ByteArray(total)

        // IPv4 header
        out[0] = 0x45
        out[1] = 0
        out[2] = ((total shr 8) and 0xFF).toByte()
        out[3] = (total and 0xFF).toByte()
        out[8] = 64 // TTL
        out[9] = 17 // UDP
        System.arraycopy(VPN_DNS.toIpBytes(), 0, out, 12, 4)  // src = خادمنا الوهمي
        System.arraycopy(phoneIp, 0, out, 16, 4)              // dst = الجهاز

        // UDP header — src 53 / dst منفذ العميل الأصلي
        out[20] = 0; out[21] = 53
        out[22] = ((phonePort shr 8) and 0xFF).toByte()
        out[23] = (phonePort and 0xFF).toByte()
        val udpLen = dnsLength + 8
        out[24] = ((udpLen shr 8) and 0xFF).toByte()
        out[25] = (udpLen and 0xFF).toByte()
        out[26] = 0; out[27] = 0 // UDP checksum = 0 (مسموح في IPv4)

        System.arraycopy(dnsPayload, 0, out, 28, dnsLength)

        fixIpv4Checksum(out)
        return out
    }

    /** تصحيح UDP length بعد أي تعديل على الحزمة */
    private fun fixUdpLength(packet: ByteArray, extra: Int = 0) {
        val ipHeaderLen = (packet[0].toInt() and 0x0F) * 4
        val udpLen = packet.size - ipHeaderLen + extra
        packet[ipHeaderLen + 4] = ((udpLen shr 8) and 0xFF).toByte()
        packet[ipHeaderLen + 5] = (udpLen and 0xFF).toByte()
    }

    /** تصحيح IPv4 total length */
    private fun fixIpv4TotalLength(packet: ByteArray) {
        packet[2] = ((packet.size shr 8) and 0xFF).toByte()
        packet[3] = (packet.size and 0xFF).toByte()
    }

    private fun fixIpv4Checksum(packet: ByteArray) {
        packet[10] = 0; packet[11] = 0
        var sum = 0L
        var i = 0
        val headerLen = (packet[0].toInt() and 0x0F) * 4
        while (i < headerLen) {
            sum += ((packet[i].toInt() and 0xFF) shl 8) or (packet[i + 1].toInt() and 0xFF)
            i += 2
        }
        while (sum > 0xFFFFL) {
            sum = (sum and 0xFFFFL) + (sum shr 16)
        }
        val checksum = (sum.inv().toInt()) and 0xFFFF
        packet[10] = ((checksum shr 8) and 0xFF).toByte()
        packet[11] = (checksum and 0xFF).toByte()
    }

    private fun fixUdpLengthAndChecksum(packet: ByteArray) {
        val ipHeaderLen = (packet[0].toInt() and 0x0F) * 4
        val udpLen = packet.size - ipHeaderLen
        packet[ipHeaderLen + 4] = ((udpLen shr 8) and 0xFF).toByte()
        packet[ipHeaderLen + 5] = (udpLen and 0xFF).toByte()
        packet[ipHeaderLen + 6] = 0
        packet[ipHeaderLen + 7] = 0
    }

    private fun String.toIpBytes(): ByteArray =
        split('.').map { it.toInt().and(0xFF).toByte() }.toByteArray()

    // ============ الإيقاف والإشعار ============

    private fun stopVpn() {
        stopping = true
        worker?.interrupt()
        vpnInterface?.close()
        vpnInterface = null
        isRunning = false
        Log.i(TAG, "DNS filter VPN stopped")
    }

    private fun startForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID, "حماية المحتوى", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "فلترة المواقع الإباحية نشطة"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("NAP-EX")
                .setContentText("حماية المحتوى نشطة — فلترة المواقع")
                .setSmallIcon(android.R.drawable.ic_secure)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("NAP-EX")
                .setContentText("حماية المحتوى نشطة")
                .setSmallIcon(android.R.drawable.ic_secure)
                .setOngoing(true)
                .build()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isRunning = true
    }

    override fun onDestroy() {
        stopping = true
        upstreamExecutor.shutdownNow()
        worker?.interrupt()
        vpnInterface?.close()
        vpnInterface = null
        isRunning = false
        super.onDestroy()
    }
}
