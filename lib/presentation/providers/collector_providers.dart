import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:napex_victim_app/core/constants/db_constants.dart';
import 'package:napex_victim_app/core/utils/logger.dart';
import 'package:napex_victim_app/data/datasources/local/daos/blocklist_dao.dart';
import 'package:napex_victim_app/data/services/blocklist_sync_service.dart';
import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/message.dart';
import 'package:napex_victim_app/domain/entities/message_category.dart';
import 'package:napex_victim_app/domain/entities/risk_level.dart';
import 'package:napex_victim_app/domain/entities/sender.dart';
import 'package:napex_victim_app/domain/repositories/collector_repository.dart';
import 'package:napex_victim_app/domain/repositories/message_repository.dart';
import 'package:napex_victim_app/domain/repositories/ml_repository.dart';
import 'package:napex_victim_app/domain/repositories/settings_repository.dart';
import 'package:napex_victim_app/domain/usecases/collector/collection_usecases.dart';
import 'package:napex_victim_app/domain/usecases/collector/process_message_usecase.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/providers/settings_providers.dart';
import 'package:napex_victim_app/presentation/services/notification_service.dart';

/// حالة الجمع والحماية
enum CollectorStatus { idle, starting, running, stopping, error }

class CollectorState {
  const CollectorState({
    this.status = CollectorStatus.idle,
    this.accessibilityEnabled = false,
    this.notificationListenerEnabled = false,
    this.lastAlert,
    this.processedCount = 0,
    this.detectedCount = 0,
    this.error,
  });

  final CollectorStatus status;
  final bool accessibilityEnabled;
  final bool notificationListenerEnabled;
  final ProcessMessageResult? lastAlert;
  final int processedCount;
  final int detectedCount;
  final String? error;

  bool get isRunning => status == CollectorStatus.running;

  CollectorState copyWith({
    CollectorStatus? status,
    bool? accessibilityEnabled,
    bool? notificationListenerEnabled,
    ProcessMessageResult? lastAlert,
    bool clearAlert = false,
    int? processedCount,
    int? detectedCount,
    String? error,
    bool clearError = false,
  }) {
    return CollectorState(
      status: status ?? this.status,
      accessibilityEnabled:
          accessibilityEnabled ?? this.accessibilityEnabled,
      notificationListenerEnabled:
          notificationListenerEnabled ?? this.notificationListenerEnabled,
      lastAlert: clearAlert ? null : (lastAlert ?? this.lastAlert),
      processedCount: processedCount ?? this.processedCount,
      detectedCount: detectedCount ?? this.detectedCount,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// متحكم الجمع — يستقبل الرسائل من خدمات النظام ويعالجها وينبه المستخدم
class CollectorController extends StateNotifier<CollectorState> {
  CollectorController(
    this._collectorRepository,
    this._messageRepository,
    this._mlRepository,
    this._processMessage,
    this._startCollection,
    this._stopCollection,
    this._notifications,
    this._isAutoReportEnabled,
    this._blocklistDao,
    this._blocklistSync,
    this._personalBlocklistDao,
    this._getSettings,
  ) : super(const CollectorState()) {
    _init();
  }

  final CollectorRepository _collectorRepository;
  final MessageRepository _messageRepository;
  final MLRepository _mlRepository;
  final ProcessMessageUseCase _processMessage;
  final StartCollectionUseCase _startCollection;
  final StopCollectionUseCase _stopCollection;
  final AppNotificationService _notifications;
  final bool Function() _isAutoReportEnabled;
  final BlocklistDao _blocklistDao;
  final BlocklistSyncService _blocklistSync;
  final PersonalBlocklistDao _personalBlocklistDao;
  final AppSettings Function() _getSettings;

  StreamSubscription<CollectedMessage>? _subscription;
  final Uuid _uuid = const Uuid();

  // حماية من فيض الأحداث (خلل برمجي أو تكرار البث)
  static const int _maxMessagesPerMinute = 30;
  int _windowCount = 0;
  DateTime _windowStart = DateTime.now();
  DateTime _lastAlertAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _init() async {
    // تهيئة محرك التحليل + مزامنة القائمتين + تنظيف الرسائل القديمة
    await _mlRepository.loadModel();
    await _blocklistSync.sync();
    await _messageRepository.deleteOldMessages(
      olderThan: DbConstants.messageRetentionPeriod,
    );
    await refreshPermissions();
  }

  /// تحديث حالة الأذونات من النظام
  Future<void> refreshPermissions() async {
    final accessibility = await _collectorRepository.isAccessibilityEnabled();
    final notifications =
        await _collectorRepository.isNotificationListenerEnabled();
    state = state.copyWith(
      accessibilityEnabled: accessibility,
      notificationListenerEnabled: notifications,
    );
  }

  /// بدء الحماية (الاستماع للرسائل)
  Future<void> start() async {
    if (state.isRunning) return;
    state = state.copyWith(status: CollectorStatus.starting, clearError: true);

    final result = await _startCollection();
    result.fold(
      (failure) {
        // الخدمة الأساسية غير مفعّلة — الحالة تبقى خطأ مع إرشاد المستخدم
        state = state.copyWith(
          status: CollectorStatus.error,
          error: failure.message,
        );
        refreshPermissions();
      },
      (_) {
        _subscription?.cancel();
        _subscription = _collectorRepository.messageStream.listen(
          _onMessage,
          onError: (Object e) {
            AppLogger.error('Message stream error', tag: 'Collector', error: e);
          },
        );
        state = state.copyWith(status: CollectorStatus.running, clearError: true);
        AppLogger.info('Collector started', tag: 'Collector');
      },
    );
  }

  /// إيقاف الحماية
  Future<void> stop() async {
    state = state.copyWith(status: CollectorStatus.stopping);
    await _subscription?.cancel();
    _subscription = null;
    await _stopCollection();
    state = state.copyWith(status: CollectorStatus.idle);
  }

  /// المعالجة الكاملة لرسالة واردة
  Future<void> _onMessage(CollectedMessage message) async {
    // 0. حد أمان ضد فيض الأحداث (1000 رسالة/دقيقة = خلل وليست حماية)
    final now = DateTime.now();
    if (now.difference(_windowStart) > const Duration(minutes: 1)) {
      _windowStart = now;
      _windowCount = 0;
    }
    _windowCount++;
    if (_windowCount > _maxMessagesPerMinute) {
      AppLogger.warning(
        'Message flood throttled ($_windowCount/min)',
        tag: 'Collector',
      );
      return;
    }

    // 1ب. احترام قائمة التطبيقات المُراقَبة التي اختارها المستخدم
    final settings = _getSettings();
    if (!settings.isPackageMonitored(message.source.packageName)) {
      AppLogger.info(
        'Skipped message from unmonitored package: ${message.source.packageName}',
        tag: 'Collector',
      );
      return;
    }

    // 2. منع التكرار — الرسائل النصية قد تُسلَّم مرتين؛ المعرف الأصلي حتمي
    if (await _messageRepository.messageExists(message.id)) {
      AppLogger.info('Duplicate message skipped: ${message.id}', tag: 'Collector');
      return;
    }

    // 2. حفظ الرسالة مشفرة (سجل مؤقت مع سياسة احتفاظ)
    final (saved, saveFailure) = await _messageRepository.saveMessage(message);
    if (saveFailure != null) {
      AppLogger.error('Save message failed', tag: 'Collector', error: saveFailure);
    }

    // 3. فحص قائمة الحظر الوطنية — مرسل مُدان سابقاً = ابتزاز مؤكد
    AnalysisResult? forcedAnalysis;
    final blockHit = await _blocklistDao.findByHashOrPhone(
      senderHash: message.sender.senderHash ?? '',
      phone: message.sender.phoneNumber,
    );
    if (blockHit != null) {
      AppLogger.warning(
        'Blocklisted sender detected: ${message.sender.raw}',
        tag: 'Collector',
      );
      forcedAnalysis = _blocklistAnalysis(
        blockHit['display_name']?.toString() ?? 'blacklisted',
        'national-blocklist',
        'هذا المرسل مدرج في قائمة الحظر الوطنية لمُدانة سابقة بالابتزاز',
      );
    }

    // 3ب. فحص قائمة الحظر الشخصية — أرقام حظرها المستخدم بنفسه
    if (forcedAnalysis == null) {
      final personalHit = await _personalBlocklistDao.findByHashOrPhone(
        senderHash: message.sender.senderHash ?? '',
        phone: message.sender.phoneNumber,
      );
      if (personalHit != null) {
        forcedAnalysis = _blocklistAnalysis(
          personalHit['display_name']?.toString() ?? 'personal-blocked',
          'personal-blocklist',
          'هذا المرسل موجود في قائمة الحظر الشخصية الخاصة بك',
        );
      }
    }

    // 4. التحليل + الإنشاء التلقائي للبلاغ عند الابتزاز المؤكد
    final target = saved ?? message;
    final result = await _processMessage(
      ProcessMessageParams(
        message: target,
        autoReport: _isAutoReportEnabled(),
        forcedAnalysis: forcedAnalysis,
        detectionThreshold: settings.sensitivity.threshold,
      ),
    );

    result.fold(
      (failure) => state = state.copyWith(
        processedCount: state.processedCount + 1,
        error: failure.message,
      ),
      (processed) {
        final detected = processed.reportCreated;
        final shouldAlert = processed.needsUserAlert;

        state = state.copyWith(
          processedCount: state.processedCount + 1,
          detectedCount: state.detectedCount + (detected ? 1 : 0),
          lastAlert: shouldAlert ? processed : null,
          clearError: true,
        );

        // 5. إشعار المستخدم — حسب نمط التنبيه وساعات الحماية
        final canNotify =
            settings.notificationMode == NotificationMode.immediate &&
                settings.isWithinProtectionHours(now);
        if (shouldAlert &&
            canNotify &&
            now.difference(_lastAlertAt) > const Duration(seconds: 10)) {
          _lastAlertAt = DateTime.now();
          _notifications.showExtortionAlert(
            title: '⚠️ تم اكتشاف رسالة ابتزاز',
            body: 'من ${target.sender.displayName} — افتح التطبيق لعرض التفاصيل',
          );
        }
      },
    );
  }

  /// رسالة اختبار يدوية (زر "تحليل رسالة" في لوحة التحكم)
  Future<ProcessMessageResult?> analyzeManually(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;

    final message = CollectedMessage(
      id: _uuid.v4(),
      sender: Sender(raw: 'test', displayName: 'رسالة اختبار'),
      content: trimmed,
      source: MessageSource.sms,
      timestamp: DateTime.now(),
    );

    final (saved, _) = await _messageRepository.saveMessage(message);
    final result = await _processMessage(
      ProcessMessageParams(
        message: saved ?? message,
        // التحليل اليدوي: تحليل وتنبيه فقط — لا بلاغ (البلاغات من المصادر
        // الحقيقية فقط: واتس/انستا/تيليجرام/رسائل... وفيها معلومات المبتز)
        autoReport: false,
        detectionThreshold: _getSettings().sensitivity.threshold,
      ),
    );

    ProcessMessageResult? returnedResult;
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (processed) {
        returnedResult = processed;
        if (processed.reportCreated) {
          state = state.copyWith(
            detectedCount: state.detectedCount + 1,
            lastAlert: processed.needsUserAlert ? processed : null,
          );
        }
      },
    );
    return returnedResult;
  }

  /// وضع الطوارئ — بلاغ عاجل مفروض (PANIC) بغض النظر عن أي تحليل
  Future<ProcessMessageResult?> triggerPanic() async {
    final message = CollectedMessage(
      id: _uuid.v4(),
      sender: Sender(raw: 'panic', displayName: 'وضع الطوارئ'),
      content: '🆘 طلب مساعدة عاجل من المستخدم — وضع الطوارئ مفعل',
      source: MessageSource.sms,
      timestamp: DateTime.now(),
    );

    final (saved, _) = await _messageRepository.saveMessage(message);
    final result = await _processMessage(
      ProcessMessageParams(
        message: saved ?? message,
        forcedAnalysis: AnalysisResult(
          category: MessageCategory.threat,
          confidence: 1.0,
          riskLevel: RiskLevel.critical,
          isExtortion: false,
          recommendations: const [
            'تواصل مع الجهات الأمنية فوراً إذا كان الخطر مباشراً',
            'أبلغ جهاتك الموثوقة من شاشة مشاركة النص',
          ],
          analysisEngine: 'panic-mode',
        ),
        // الطوارئ: تنبيه ومشاركة فقط — لا بلاغ إجباري بلا ابتزاز فعلي
        autoReport: false,
      ),
    );

    ProcessMessageResult? returnedResult;
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (processed) {
        returnedResult = processed;
        state = state.copyWith(
          detectedCount: state.detectedCount + 1,
          lastAlert: processed,
        );
        // الطوارئ تتجاوز نمط التنبيه الصامت وساعات الهدوء
        _notifications.showExtortionAlert(
          title: '🆘 وضع الطوارئ مفعّل',
          body: 'تم إنشاء بلاغ عاجل — شارك رسالة الإشعار مع جهاتك الموثوقة',
        );
      },
    );
    return returnedResult;
  }

  AnalysisResult _blocklistAnalysis(
    String displayName,
    String engine,
    String recommendation,
  ) {
    return AnalysisResult(
      category: MessageCategory.extortion,
      confidence: 0.99,
      riskLevel: RiskLevel.critical,
      isExtortion: true,
      keywords: [displayName],
      threatPhrases: const [],
      recommendations: <String>[
        recommendation,
        'أبلغ فوراً — بلاغك يوثق نشاطاً متكرراً',
      ],
      analysisEngine: engine,
    );
  }

  /// مسح التنبيه الحالي
  void clearAlert() => state = state.copyWith(clearAlert: true);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final collectorProvider =
    StateNotifierProvider<CollectorController, CollectorState>((ref) {
  return CollectorController(
    ref.watch(collectorRepositoryProvider),
    ref.watch(messageRepositoryProvider),
    ref.watch(mlRepositoryProvider),
    ref.watch(processMessageUseCaseProvider),
    ref.watch(startCollectionUseCaseProvider),
    ref.watch(stopCollectionUseCaseProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(autoReportEnabledProvider),
    ref.watch(blocklistDaoProvider),
    ref.watch(blocklistSyncServiceProvider),
    ref.watch(personalBlocklistDaoProvider),
    () => ref.read(settingsProvider),
  );
});
