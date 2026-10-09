import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/utils/arabic_normalizer.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/repositories/evidence_repository.dart';
import 'package:napex_victim_app/domain/repositories/report_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/get_reports_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/sync_reports_usecase.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';

/// حالة قائمة البلاغات
class ReportsState {
  const ReportsState({
    this.reports = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.lastSyncMessage,
    this.filterStatus = '',
    this.filterCategory = '',
    this.searchQuery = '',
  });

  final List<Report> reports;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final String? lastSyncMessage;

  // ============ فلاتر العرض ============
  final String filterStatus; // '' = الكل
  final String filterCategory; // '' = الكل
  final String searchQuery;

  int get pendingCount => reports
      .where((r) => r.status.needsSubmission || r.status == ReportStatus.pending)
      .length;

  int get detectedCount => reports.where((r) => r.isExtortion).length;

  /// البلاغات بعد تطبيق الفلاتر والبحث (تطبيع عربي للبحث)
  List<Report> get visibleReports {
    var list = reports;

    if (filterStatus.isNotEmpty) {
      list = list
          .where((r) => r.status.value == filterStatus)
          .toList();
    }
    if (filterCategory.isNotEmpty) {
      list = list
          .where((r) => r.analysis.category.value == filterCategory)
          .toList();
    }

    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      final normalized = ArabicNormalizer.normalize(query);
      final rawLower = query.toLowerCase();
      list = list.where((r) {
        final number = r.reportNumber?.toLowerCase() ?? '';
        return ArabicNormalizer.normalize(r.content).contains(normalized) ||
            ArabicNormalizer.normalize(r.sender.displayName)
                .contains(normalized) ||
            number.contains(rawLower);
      }).toList();
    }

    return list;
  }

  bool get hasActiveFilters =>
      filterStatus.isNotEmpty ||
      filterCategory.isNotEmpty ||
      searchQuery.trim().isNotEmpty;

  ReportsState copyWith({
    List<Report>? reports,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    bool clearError = false,
    String? lastSyncMessage,
    bool clearSyncMessage = false,
    String? filterStatus,
    String? filterCategory,
    String? searchQuery,
  }) {
    return ReportsState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      lastSyncMessage:
          clearSyncMessage ? null : (lastSyncMessage ?? this.lastSyncMessage),
      filterStatus: filterStatus ?? this.filterStatus,
      filterCategory: filterCategory ?? this.filterCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// متحكم البلاغات — بث مباشر من قاعدة البيانات
class ReportsController extends StateNotifier<ReportsState> {
  ReportsController(
    this._getReports,
    this._syncReports,
    this._reportRepository,
    this._evidenceRepository,
  ) : super(const ReportsState()) {
    _subscribe();
  }

  final GetReportsUseCase _getReports;
  final SyncReportsUseCase _syncReports;
  final ReportRepository _reportRepository;
  final EvidenceRepository _evidenceRepository;

  StreamSubscription<EitherLike>? _subscription;

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _getReports(NoParams()).listen(
      (either) {
        either.fold(
          (Failure failure) =>
              state = state.copyWith(error: failure.message, isLoading: false),
          (List<Report> reports) =>
              state = state.copyWith(reports: reports, isLoading: false),
        );
      },
      onError: (Object e) =>
          state = state.copyWith(error: e.toString(), isLoading: false),
    );
  }

  /// مزامنة البلاغات المعلقة مع الخادم
  Future<void> sync() async {
    state = state.copyWith(isSyncing: true, clearError: true);
    final result = await _syncReports();
    result.fold(
      (failure) => state = state.copyWith(
        isSyncing: false,
        error: failure.message,
      ),
      (count) => state = state.copyWith(
        isSyncing: false,
        clearSyncMessage: true,
        lastSyncMessage:
            count > 0 ? 'تم إرسال $count بلاغ بنجاح' : 'لا توجد بلاغات معلقة',
      ),
    );
  }

  /// حذف بلاغ
  Future<void> delete(String id) async {
    await _reportRepository.deleteReport(id);
  }

  /// إرفاق دليل نصي مشفر ببلاغ
  Future<bool> attachEvidence(Report report) async {
    final (evidence, failure) =
        await _evidenceRepository.createTextEvidence(report: report);
    if (failure != null) {
      state = state.copyWith(error: failure.message);
      return false;
    }
    return evidence != null;
  }

  /// تحديث بلاغ واحد بعد أي تغيير
  Future<void> refreshReport(String id) async {
    final (report, _) = await _reportRepository.getReportById(id);
    if (report == null) return;
    final updated = state.reports
        .map((r) => r.localId == report.localId ? report : r)
        .toList();
    state = state.copyWith(reports: updated);
  }

  /// جلب بلاغ واحد بالمعرف (لشاشة التفاصيل)
  Future<Report?> loadById(String id) async {
    final (report, _) = await _reportRepository.getReportById(id);
    return report;
  }

  // ============ الفلاتر ============

  void setStatusFilter(String value) =>
      state = state.copyWith(filterStatus: value);

  void setCategoryFilter(String value) =>
      state = state.copyWith(filterCategory: value);

  void setSearchQuery(String value) =>
      state = state.copyWith(searchQuery: value);

  void clearFilters() => state = state.copyWith(
        filterStatus: '',
        filterCategory: '',
        searchQuery: '',
      );

  void clearMessages() =>
      state = state.copyWith(clearError: true, clearSyncMessage: true);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final reportsProvider =
    StateNotifierProvider<ReportsController, ReportsState>((ref) {
  return ReportsController(
    ref.watch(getReportsUseCaseProvider),
    ref.watch(syncReportsUseCaseProvider),
    ref.watch(reportRepositoryProvider),
    ref.watch(evidenceRepositoryProvider),
  );
});

/// Alias لتبسيط تعريف النوع في الاشتراك
typedef EitherLike = dynamic;
