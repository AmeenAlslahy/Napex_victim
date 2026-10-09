import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/constants/api_constants.dart';

/// واجهة رفع الأدلة الرقمية
class EvidenceApi {
  EvidenceApi(this._dio);

  final Dio _dio;

  /// رفع ملف دليل مشفر مع تجزئته
  Future<Map<String, dynamic>> upload({
    required MultipartFile file,
    required String reportId,
    required String fileHash,
  }) async {
    final formData = FormData.fromMap({
      'file': file,
      'report_id': reportId,
      'file_hash': fileHash,
    });

    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.uploadEvidence,
      data: formData,
    );
    return response.data ?? <String, dynamic>{};
  }
}
