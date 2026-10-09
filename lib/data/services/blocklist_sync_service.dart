import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/constants/api_constants.dart';
import 'package:napex_victim_app/core/utils/logger.dart';
import 'package:napex_victim_app/data/datasources/local/daos/blocklist_dao.dart';

/// مزامنة قائمة الحظر الوطنية من الخادم إلى النسخة المحلية
/// (تعمل بشكل متسامح: الفشل لا يعطّل التطبيق — القائمة القديمة تبقى صالحة)
class BlocklistSyncService {
  BlocklistSyncService({required Dio dio, required BlocklistDao dao})
      : _dio = dio,
        _dao = dao;

  final Dio _dio;
  final BlocklistDao _dao;

  Future<int> sync() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiConstants.blocklist);
      final rows = _parse(response.data);
      await _dao.replaceAll(rows);
      AppLogger.info('Blocklist synced: ${rows.length} entries', tag: 'Blocklist');
      return rows.length;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // المستخدم غير مسجّل بعد — تجاهل بهدوء (لا ضجيج في السجل)
        AppLogger.info('Blocklist sync skipped (unauthenticated)', tag: 'Blocklist');
        return 0;
      }
      AppLogger.warning('Blocklist sync failed (offline?): $e', tag: 'Blocklist');
      return 0;
    } catch (e) {
      AppLogger.warning('Blocklist sync failed (offline?): $e', tag: 'Blocklist');
      return 0;
    }
  }
}

List<Map<String, Object?>> _parse(List<dynamic>? data, {bool hasReportRef = true}) {
  final rows = <Map<String, Object?>>[];
  for (final item in data ?? const []) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    rows.add({
      'id': map['id']?.toString() ?? '',
      'sender_hash': map['sender_hash']?.toString() ?? '',
      'phone_number': map['phone_number']?.toString(),
      'display_name': map['display_name']?.toString() ?? '',
      'reason': map['reason']?.toString() ?? '',
      if (hasReportRef) 'related_report_id': map['related_report_id']?.toString(),
      'added_at': DateTime.tryParse(map['added_at']?.toString() ?? '')
              ?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    });
  }
  return rows;
}
