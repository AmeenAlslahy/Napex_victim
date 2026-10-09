package com.napex.napex_victim_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

import com.napex.napex_victim_app.channels.ContentSafetyChannel
import com.napex.napex_victim_app.channels.MessageCollectorChannel
import com.napex.napex_victim_app.channels.SecurityChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // تسجيل قنوات المنصة: جمع الرسائل + الأمان + حماية المحتوى
        MessageCollectorChannel(applicationContext, messenger).register()
        SecurityChannel(applicationContext, messenger).register()
        // هذا النشاط وليس applicationContext — حوار موافقة VPN يتطلب Activity
        ContentSafetyChannel(this, messenger).register()
    }
}
