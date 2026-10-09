import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/constants/api_constants.dart';

/// واجهات الضحية: الإشعارات، التغذية الراجعة، تصدير البيانات
/// (الحظر الشخصي محلي 100% على الجهاز — لا يُرسل للخادم إطلاقاً)
class VictimApi {
  VictimApi(this._dio);

  final Dio _dio;

  // ============ الإشعارات ============

  Future<List<dynamic>> fetchMyNotifications() async {
    final response = await _dio.get<List<dynamic>>(
      ApiConstants.victimNotifications,
    );
    return response.data ?? [];
  }

  Future<void> markRead(String notificationId) =>
      _dio.patch('${ApiConstants.victimNotifications}/$notificationId/read');

  // ============ التغذية الراجعة على الكشف ============

  Future<void> submitFeedback({
    required String reportId,
    required String feedbackType,
    String? reason,
    String? extortionKind,
  }) =>
      _dio.post(
        '${ApiConstants.reports}/$reportId/feedback',
        data: {
          'feedback_type': feedbackType,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (extortionKind != null) 'extortion_kind': extortionKind,
        },
      );

  // ============ تصدير البيانات ============

  Future<String> exportMyData() async {
    final response = await _dio.get<String>(
      '${ApiConstants.apiPrefix}/me/export',
    );
    return response.data ?? '';
  }
}
