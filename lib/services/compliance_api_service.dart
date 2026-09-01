import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/verification_request.dart';
import '../core/metadata_header_factory.dart';
import '../core/fail_closed_validator.dart';
import '../core/lineage_exception.dart';

class ComplianceApiResult {
  final bool success;
  final bool quarantined;
  final String? message;
  const ComplianceApiResult({required this.success, required this.quarantined, this.message});
}

class ComplianceApiService {
  static const endpoint = 'https://api.habotconnect.com/v1/compliance/verify';
  final http.Client? _client;
  final bool useMockMode;

  ComplianceApiService({http.Client? client, this.useMockMode = true})
      : _client = client;

  Future<ComplianceApiResult> submit(
    VerificationRequest request, {
    bool simulate500 = false,
  }) async {
    FailClosedValidator.assertValidLineage(request.predecessorId);

    final body = jsonEncode(request.toJson());
    final traceId = MetadataHeaderFactory.generateTraceId();
    final logicHash = MetadataHeaderFactory.generateLogicHash(body);
    final headers = MetadataHeaderFactory.buildHeaders(traceId: traceId, logicHash: logicHash);

    if (_client != null) {
      try {
        final response = await _client
            .post(Uri.parse(endpoint), headers: headers, body: body)
            .timeout(const Duration(seconds: 10));

        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = null;
        }

        final mustQuarantine = FailClosedValidator.isResponseQuarantinable(
          statusCode: response.statusCode,
          decodedBody: decoded,
        );

        if (mustQuarantine) {
          return const ComplianceApiResult(
            success: false,
            quarantined: true,
            message: 'Data Quarantined – Compliance Failure',
          );
        }

        return const ComplianceApiResult(
          success: true,
          quarantined: false,
          message: 'Verified successfully.',
        );
      } on LineageException {
        rethrow;
      } catch (_) {
        return const ComplianceApiResult(
          success: false,
          quarantined: true,
          message: 'Data Quarantined – Compliance Failure',
        );
      }
    }

    if (useMockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (simulate500 ||
          request.parentConsentCode == 'FORCE_500' ||
          request.parentConsentCode == 'NULL_STATUS') {
        return const ComplianceApiResult(
          success: false,
          quarantined: true,
          message: 'Data Quarantined – Compliance Failure',
        );
      }

      if (request.parentConsentCode == 'PCC-2026-9901') {
        return const ComplianceApiResult(
          success: true,
          quarantined: false,
          message: 'Verified successfully.',
        );
      }

      return const ComplianceApiResult(
        success: false,
        quarantined: true,
        message: 'Data Quarantined – Compliance Failure',
      );
    }

    try {
      final response = await http
          .post(Uri.parse(endpoint), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      final mustQuarantine = FailClosedValidator.isResponseQuarantinable(
        statusCode: response.statusCode,
        decodedBody: decoded,
      );

      if (mustQuarantine) {
        return const ComplianceApiResult(
          success: false,
          quarantined: true,
          message: 'Data Quarantined – Compliance Failure',
        );
      }

      return const ComplianceApiResult(
        success: true,
        quarantined: false,
        message: 'Verified successfully.',
      );
    } on LineageException {
      rethrow;
    } catch (_) {
      return const ComplianceApiResult(
        success: false,
        quarantined: true,
        message: 'Data Quarantined – Compliance Failure',
      );
    }
  }
}