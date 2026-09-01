import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class MetadataHeaderFactory {
  static const _uuid = Uuid();

  static String generateTraceId() => _uuid.v4();

  static String generateLogicHash(String canonicalPayload) {
    final bytes = utf8.encode(canonicalPayload);
    return sha256.convert(bytes).toString();
  }

  static Map<String, String> buildHeaders({
    required String traceId,
    required String logicHash,
  }) {
    return {
      'Content-Type': 'application/json',
      'x-trace-id': traceId,
      'x-logic-hash': logicHash,
    };
  }
}