import '../models/report_request.dart';

abstract class LLMAdapter {
  String get name;
  String get defaultModel;
  List<String> get availableModels;

  Future<ReportResponse> generateReport(ReportRequest request);
  Future<bool> validateApiKey(String key);

  Stream<String> generateReportStream(ReportRequest request);
}
