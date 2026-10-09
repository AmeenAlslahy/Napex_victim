# NAP-EX — قواعد ProGuard/R8
# ملاحظة: التصغير معطّل حالياً في build.gradle.kts — فعّله عند الإنتاج مع هذه القواعد.

# ============ Flutter ============
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ============ flutter_local_notifications ============
-keep class com.dexterous.** { *; }

# ============ Kotlin ============
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlin.Metadata { *; }

# ============ SQLite (sqflite) ============
-keep class com.tekartik.sqflite.** { *; }
