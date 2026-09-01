import 'lineage_exception.dart';

class FailClosedValidator {
  static void assertValidLineage(String? predecessorId) {
    if (predecessorId == null || predecessorId.trim().isEmpty) {
      throw const LineageException();
    }
  }

  static bool isResponseQuarantinable({
    required int? statusCode,
    required dynamic decodedBody,
  }) {
    if (statusCode == null || statusCode >= 500) return true;
    if (decodedBody is Map && decodedBody['status'] == null) return true;
    return false;
  }
}