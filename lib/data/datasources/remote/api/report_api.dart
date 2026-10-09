import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/constants/api_constants.dart';

/// واجهة بلاغات الخادم
class ReportApi {
  ReportApi(this._dio);

  final Dio _dio;

  /// إرسال بلاغ — يُعيد استجابة الخادم (رقم البلاغ + الحالة)
  Future<Map<String, dynamic>> submit(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.reports,
      data: body,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getReport(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.reportById(id),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<dynamic>> listReports({
    String? status,
    int? page,
    int? pageSize,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      ApiConstants.reports,
      queryParameters: {
        if (status != null) 'status': status,
        if (page != null) 'page': page,
        if (pageSize != null) 'page_size': pageSize,
      },
    );
    return response.data ?? [];
  }

  Future<void> updateStatus(String id, Map<String, dynamic> body) =>
      _dio.patch(ApiConstants.reportStatus(id), data: body);
}
