import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:napex_victim_app/core/constants/security_constants.dart';
import 'package:napex_victim_app/core/network/dio_client.dart';
import 'package:napex_victim_app/core/network/interceptors/auth_interceptor.dart';
import 'package:napex_victim_app/core/network/interceptors/logging_interceptor.dart';
import 'package:napex_victim_app/core/network/interceptors/signature_interceptor.dart';
import 'package:napex_victim_app/core/network/network_info.dart';
import 'package:napex_victim_app/core/security/encryption_service.dart';
import 'package:napex_victim_app/core/security/hash_service.dart';
import 'package:napex_victim_app/core/security/secure_storage.dart';
import 'package:napex_victim_app/core/storage/local_storage.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';
import 'package:napex_victim_app/data/datasources/local/daos/audit_dao.dart';
import 'package:napex_victim_app/data/datasources/local/daos/blocklist_dao.dart';
import 'package:napex_victim_app/data/datasources/local/daos/evidence_dao.dart';
import 'package:napex_victim_app/data/datasources/local/daos/message_dao.dart';
import 'package:napex_victim_app/data/datasources/local/daos/report_dao.dart';import 'package:napex_victim_app/data/datasources/ml/keyword_classifier.dart';
import 'package:napex_victim_app/data/datasources/remote/api/auth_api.dart';
import 'package:napex_victim_app/data/datasources/remote/api/evidence_api.dart';
import 'package:napex_victim_app/data/datasources/remote/api/report_api.dart';
import 'package:napex_victim_app/data/datasources/remote/api/victim_api.dart';
import 'package:napex_victim_app/data/repositories/auth_repository_impl.dart';
import 'package:napex_victim_app/data/repositories/collector_repository_impl.dart';
import 'package:napex_victim_app/data/repositories/evidence_repository_impl.dart';
import 'package:napex_victim_app/data/repositories/message_repository_impl.dart';
import 'package:napex_victim_app/data/repositories/ml_repository_impl.dart';
import 'package:napex_victim_app/data/repositories/report_repository_impl.dart';
import 'package:napex_victim_app/data/repositories/settings_repository_impl.dart';
import 'package:napex_victim_app/data/services/blocklist_sync_service.dart';
import 'package:napex_victim_app/domain/repositories/auth_repository.dart';
import 'package:napex_victim_app/domain/repositories/collector_repository.dart';import 'package:napex_victim_app/domain/repositories/evidence_repository.dart';
import 'package:napex_victim_app/domain/repositories/message_repository.dart';
import 'package:napex_victim_app/domain/repositories/ml_repository.dart';
import 'package:napex_victim_app/domain/repositories/report_repository.dart';
import 'package:napex_victim_app/domain/repositories/settings_repository.dart';
import 'package:napex_victim_app/domain/usecases/analysis/analyze_message_usecase.dart';
import 'package:napex_victim_app/domain/usecases/auth/logout_usecase.dart';
import 'package:napex_victim_app/domain/usecases/auth/register_user_usecase.dart';
import 'package:napex_victim_app/domain/usecases/auth/verify_otp_usecase.dart';
import 'package:napex_victim_app/domain/usecases/collector/collection_usecases.dart';
import 'package:napex_victim_app/domain/usecases/collector/process_message_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/create_report_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/get_reports_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/submit_report_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/sync_reports_usecase.dart';
import 'package:napex_victim_app/platform/channels/message_collector_channel.dart';
import 'package:napex_victim_app/platform/channels/security_channel.dart';
import 'package:napex_victim_app/presentation/services/notification_service.dart';

// ====================================================================
// هذه الـ Providers تُحقن (override) من bootstrap قبل تشغيل التطبيق
// ====================================================================

final localStorageProvider = Provider<LocalStorage>(
  (ref) => throw UnimplementedError('يُحقن من bootstrap'),
);

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('يُحقن من bootstrap'),
);

final initialAuthenticatedProvider = Provider<bool>(
  (ref) => throw UnimplementedError('يُحقن من bootstrap'),
);

// ====================================================================
// Core
// ====================================================================

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(const FlutterSecureStorage()),
);

final connectivityProvider = Provider<Connectivity>(
  (ref) => Connectivity(),
);

final networkInfoProvider = Provider<NetworkInfo>(
  (ref) => NetworkInfo(ref.watch(connectivityProvider)),
);

final hashServiceProvider = Provider<HashService>((ref) => const HashService());

final encryptionServiceProvider = Provider<EncryptionService>(
  (ref) => EncryptionService(ref.watch(secureStorageProvider)),
);

// ====================================================================
// Network
// ====================================================================

final authInterceptorProvider = Provider<AuthInterceptor>(
  (ref) => AuthInterceptor(
    secureStorage: ref.watch(secureStorageProvider),
    onTokenExpired: () async {
      await ref
          .read(secureStorageProvider)
          .delete(SecurityConstants.keyAccessToken);
    },
  ),
);

final loggingInterceptorProvider = Provider<LoggingInterceptor>(
  (ref) => LoggingInterceptor(),
);

final signatureInterceptorProvider = Provider<SignatureInterceptor>(
  (ref) => SignatureInterceptor(hashService: ref.watch(hashServiceProvider)),
);

final dioProvider = Provider<Dio>(
  (ref) => ref.watch(dioClientProvider).dio,
);

final dioClientProvider = Provider<DioClient>(
  (ref) => DioClient(
    authInterceptor: ref.watch(authInterceptorProvider),
    loggingInterceptor: ref.watch(loggingInterceptorProvider),
    signatureInterceptor: ref.watch(signatureInterceptorProvider),
  ),
);

// ====================================================================
// APIs + DAOs
// ====================================================================

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));
final reportApiProvider = Provider<ReportApi>((ref) => ReportApi(ref.watch(dioProvider)));
final evidenceApiProvider = Provider<EvidenceApi>(
  (ref) => EvidenceApi(ref.watch(dioProvider)),
);

final victimApiProvider = Provider<VictimApi>(
  (ref) => VictimApi(ref.watch(dioProvider)),
);

final blocklistSyncServiceProvider = Provider<BlocklistSyncService>(
  (ref) => BlocklistSyncService(
    dio: ref.watch(dioProvider),
    dao: ref.watch(blocklistDaoProvider),
  ),
);


final messageDaoProvider = Provider<MessageDao>(
  (ref) => MessageDao(ref.watch(appDatabaseProvider)),
);
final reportDaoProvider = Provider<ReportDao>(
  (ref) => ReportDao(ref.watch(appDatabaseProvider)),
);
final evidenceDaoProvider = Provider<EvidenceDao>(
  (ref) => EvidenceDao(ref.watch(appDatabaseProvider)),
);
final auditDaoProvider = Provider<AuditDao>(
  (ref) => AuditDao(ref.watch(appDatabaseProvider)),
);
final blocklistDaoProvider = Provider<BlocklistDao>(
  (ref) => BlocklistDao(ref.watch(appDatabaseProvider)),
);
final personalBlocklistDaoProvider = Provider<PersonalBlocklistDao>(
  (ref) => PersonalBlocklistDao(ref.watch(appDatabaseProvider)),
);

// ====================================================================
// Repositories
// ====================================================================

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    secureStorage: ref.watch(secureStorageProvider),
    localStorage: ref.watch(localStorageProvider),
  ),
);

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    reportDao: ref.watch(reportDaoProvider),
    evidenceDao: ref.watch(evidenceDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    api: ref.watch(reportApiProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    hashService: ref.watch(hashServiceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    messageDao: ref.watch(messageDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    hashService: ref.watch(hashServiceProvider),
  ),
);

final evidenceRepositoryProvider = Provider<EvidenceRepository>(
  (ref) => EvidenceRepositoryImpl(
    evidenceDao: ref.watch(evidenceDaoProvider),
    auditDao: ref.watch(auditDaoProvider),
    api: ref.watch(evidenceApiProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    hashService: ref.watch(hashServiceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final keywordClassifierProvider = Provider<KeywordClassifier>(
  (ref) => KeywordClassifier(),
);

final mlRepositoryProvider = Provider<MLRepository>(
  (ref) => MLRepositoryImpl(
    classifier: ref.watch(keywordClassifierProvider),
    dio: ref.watch(dioProvider),
  ),
);

final collectorRepositoryProvider = Provider<CollectorRepository>(
  (ref) => CollectorRepositoryImpl(
    MessageCollectorChannel(),
    ref.watch(localStorageProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(localStorageProvider)),
);

// ====================================================================
// Platform
// ====================================================================

final securityChannelProvider = Provider<SecurityChannel>(
  (ref) => SecurityChannel(),
);

final notificationServiceProvider = Provider<AppNotificationService>(
  (ref) => AppNotificationService(),
);

// ====================================================================
// UseCases
// ====================================================================

final registerUserUseCaseProvider = Provider<RegisterUserUseCase>(
  (ref) => RegisterUserUseCase(ref.watch(authRepositoryProvider)),
);

final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>(
  (ref) => VerifyOtpUseCase(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

final analyzeMessageUseCaseProvider = Provider<AnalyzeMessageUseCase>(
  (ref) => AnalyzeMessageUseCase(ref.watch(mlRepositoryProvider)),
);

final createReportUseCaseProvider = Provider<CreateReportUseCase>(
  (ref) => CreateReportUseCase(ref.watch(reportRepositoryProvider)),
);

final submitReportUseCaseProvider = Provider<SubmitReportUseCase>(
  (ref) => SubmitReportUseCase(ref.watch(reportRepositoryProvider)),
);

final syncReportsUseCaseProvider = Provider<SyncReportsUseCase>(
  (ref) => SyncReportsUseCase(ref.watch(reportRepositoryProvider)),
);

final getReportsUseCaseProvider = Provider<GetReportsUseCase>(
  (ref) => GetReportsUseCase(ref.watch(reportRepositoryProvider)),
);

final startCollectionUseCaseProvider = Provider<StartCollectionUseCase>(
  (ref) => StartCollectionUseCase(ref.watch(collectorRepositoryProvider)),
);

final stopCollectionUseCaseProvider = Provider<StopCollectionUseCase>(
  (ref) => StopCollectionUseCase(ref.watch(collectorRepositoryProvider)),
);

final processMessageUseCaseProvider = Provider<ProcessMessageUseCase>(
  (ref) => ProcessMessageUseCase(
    ref.watch(analyzeMessageUseCaseProvider),
    ref.watch(createReportUseCaseProvider),
  ),
);
