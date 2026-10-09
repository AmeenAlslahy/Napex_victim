import 'package:equatable/equatable.dart';

/// مصادر الرسائل المدعومة
enum AppSource {
  sms('sms', 'الرسائل النصية', 'com.android.mms'),
  whatsapp('com.whatsapp', 'واتساب', 'com.whatsapp'),
  whatsappBusiness(
    'com.whatsapp.w4b',
    'واتساب بزنس',
    'com.whatsapp.w4b',
  ),
  messenger('com.facebook.orca', 'ماسنجر', 'com.facebook.orca'),
  telegram('org.telegram.messenger', 'تيليجرام', 'org.telegram.messenger'),
  telegramX(
    'org.thunderdog.challegram',
    'تيليجرام X',
    'org.thunderdog.challegram',
  ),
  instagram('com.instagram.android', 'إنستجرام', 'com.instagram.android'),
  facebook('com.facebook.katana', 'فيسبوك', 'com.facebook.katana'),
  viber('com.viber.voip', 'فايبر', 'com.viber.voip'),
  imo('com.imo.android.imoim', 'IMO', 'com.imo.android.imoim'),
  signal('org.thoughtcrime.securesms', 'سيجنال', 'org.thoughtcrime.securesms'),
  snapchat('com.snapchat.android', 'سناب شات', 'com.snapchat.android'),
  tiktok('com.zhiliaoapp.musically', 'تيك توك', 'com.zhiliaoapp.musically'),
  twitter('com.twitter.android', 'تويتر/X', 'com.twitter.android'),
  line('jp.naver.line.android', 'لاين', 'jp.naver.line.android'),
  wechat('com.tencent.mm', 'ويتشات', 'com.tencent.mm'),
  unknown('unknown', 'غير معروف', 'unknown');

  const AppSource(this.packageName, this.displayName, this.nativePackage);

  final String packageName;
  final String displayName;
  final String nativePackage;

  /// البحث بواسطة اسم الحزمة (أو 'sms' للرسائل النصية)
  static AppSource fromPackageName(String packageName) {
    if (packageName == 'sms' || packageName.isEmpty) return AppSource.sms;
    return AppSource.values.firstWhere(
      (app) =>
          app.nativePackage == packageName || app.packageName == packageName,
      orElse: () => AppSource.unknown,
    );
  }

  /// هل التطبيق مشفر من الطرف للطرف؟ (تُلتقط رسائله عبر الإشعارات فقط)
  bool get isEndToEndEncrypted => const {
        AppSource.whatsapp,
        AppSource.whatsappBusiness,
        AppSource.telegram,
        AppSource.telegramX,
        AppSource.signal,
      }.contains(this);

  /// هل التطبيق مدعوم للقراءة؟
  bool get isSupported => this != AppSource.unknown;
}

/// نموذج مصدر الرسالة
class MessageSource extends Equatable {
  const MessageSource({
    required this.app,
    required this.packageName,
    this.chatId,
    this.chatName,
    this.isGroup = false,
  });

  final AppSource app;
  final String packageName;
  final String? chatId;
  final String? chatName;
  final bool isGroup;

  /// مصدر الرسائل النصية
  static const MessageSource sms = MessageSource(
    app: AppSource.sms,
    packageName: 'sms',
  );

  MessageSource copyWith({
    AppSource? app,
    String? packageName,
    String? chatId,
    String? chatName,
    bool? isGroup,
  }) {
    return MessageSource(
      app: app ?? this.app,
      packageName: packageName ?? this.packageName,
      chatId: chatId ?? this.chatId,
      chatName: chatName ?? this.chatName,
      isGroup: isGroup ?? this.isGroup,
    );
  }

  @override
  List<Object?> get props => [app, packageName, chatId, chatName, isGroup];
}
