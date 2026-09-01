import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:habot_lsa_verification/main.dart';
import 'package:habot_lsa_verification/core/fail_closed_validator.dart';
import 'package:habot_lsa_verification/core/lineage_exception.dart';
import 'package:habot_lsa_verification/core/metadata_header_factory.dart';
import 'package:habot_lsa_verification/models/verification_request.dart';
import 'package:habot_lsa_verification/screens/lsa_verification_screen.dart';
import 'package:habot_lsa_verification/services/compliance_api_service.dart';
import 'package:habot_lsa_verification/services/friction_logger.dart';

void main() {
  group('Unit Tests: Core Fail-Closed & Lineage Logic', () {
    test('VerificationRequest serialization produces expected schema', () {
      final req = VerificationRequest(
        predecessorId: 'PRED-9982-XYZ',
        lsaId: 'LSA-7049',
        parentConsentCode: 'PCC-2026-9901',
        timestampUtc: '2026-08-07T11:30:00Z',
      );
      final json = req.toJson();
      expect(json['predecessor_id'], equals('PRED-9982-XYZ'));
      expect(json['lsa_id'], equals('LSA-7049'));
      expect(json['parent_consent_code'], equals('PCC-2026-9901'));
      expect(json['timestamp_utc'], equals('2026-08-07T11:30:00Z'));
    });

    test('MetadataHeaderFactory generates UUID trace_id and SHA-256 logic_hash', () {
      final traceId = MetadataHeaderFactory.generateTraceId();
      expect(traceId, matches(r'^[0-9a-fA-F\-]{36}$'));

      final payload = '{"test":"data"}';
      final hash = MetadataHeaderFactory.generateLogicHash(payload);
      expect(hash, hasLength(64));

      final headers = MetadataHeaderFactory.buildHeaders(traceId: traceId, logicHash: hash);
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['x-trace-id'], equals(traceId));
      expect(headers['x-logic-hash'], equals(hash));
    });

    test('FailClosedValidator.assertValidLineage throws on null or empty predecessor_id (Case 2)', () {
      expect(() => FailClosedValidator.assertValidLineage(null), throwsA(isA<LineageException>()));
      expect(() => FailClosedValidator.assertValidLineage(''), throwsA(isA<LineageException>()));
      expect(() => FailClosedValidator.assertValidLineage('   '), throwsA(isA<LineageException>()));
      expect(() => FailClosedValidator.assertValidLineage('PRED-9982-XYZ'), returnsNormally);
    });

    test('FailClosedValidator.isResponseQuarantinable flags 500, null status, and invalid bodies (Case 3)', () {
      expect(FailClosedValidator.isResponseQuarantinable(statusCode: 500, decodedBody: {'status': 'ok'}), isTrue);
      expect(FailClosedValidator.isResponseQuarantinable(statusCode: 503, decodedBody: {}), isTrue);
      expect(FailClosedValidator.isResponseQuarantinable(statusCode: 200, decodedBody: {'status': null}), isTrue);
      expect(FailClosedValidator.isResponseQuarantinable(statusCode: null, decodedBody: null), isTrue);
      expect(FailClosedValidator.isResponseQuarantinable(statusCode: 200, decodedBody: {'status': 'verified'}), isFalse);
    });
  });

  group('Widget & Scenario Tests: Mock UI Spec & Test Cases', () {
    testWidgets('UI Spec: Renders header, prefilled form fields, status banner, and submit button', (tester) async {
      await tester.pumpWidget(const HabotApp());
      await tester.pumpAndSettle();

      // 1. Header
      expect(find.text('LSA Onboarding Gate'), findsOneWidget);
      expect(find.text('HabotConnect Data Compliance'), findsOneWidget);

      // 2. Form Fields
      expect(find.text('LSA-7049'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Parent Consent Code'), findsOneWidget);
      expect(find.text('predecessor_id: PRED-9982-XYZ'), findsOneWidget);

      // 3. Status Indicator
      expect(find.text('Status: Idle'), findsOneWidget);

      // 4. Action Button
      expect(find.widgetWithText(ElevatedButton, 'Verify & Submit'), findsOneWidget);
    });

    testWidgets('Case 1: Valid Submission -> Sends headers + body, UI displays Success state', (tester) async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'status': 'verified'}), 200);
      });

      final apiService = ComplianceApiService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: LsaVerificationScreen(apiService: apiService),
        ),
      );
      await tester.pumpAndSettle();

      final consentField = find.widgetWithText(TextField, 'Parent Consent Code');
      await tester.enterText(consentField, 'PCC-2026-9901');
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(ElevatedButton, 'Verify & Submit');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.toString(), equals('https://api.habotconnect.com/v1/compliance/verify'));
      expect(capturedRequest!.headers['Content-Type'], equals('application/json'));
      expect(capturedRequest!.headers['x-trace-id'], isNotNull);
      expect(capturedRequest!.headers['x-logic-hash'], isNotNull);

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['predecessor_id'], equals('PRED-9982-XYZ'));
      expect(body['lsa_id'], equals('LSA-7049'));
      expect(body['parent_consent_code'], equals('PCC-2026-9901'));
      expect(body['timestamp_utc'], isNotNull);

      expect(find.text('Status: Success'), findsOneWidget);
    });

    testWidgets('Case 2: Missing Lineage -> Blocks network call immediately, sets UI to Quarantined', (tester) async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(jsonEncode({'status': 'verified'}), 200);
      });

      final apiService = ComplianceApiService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: LsaVerificationScreen(
            apiService: apiService,
            initialPredecessorId: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final consentField = find.widgetWithText(TextField, 'Parent Consent Code');
      await tester.enterText(consentField, 'PCC-2026-9901');
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(ElevatedButton, 'Verify & Submit');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(requestCount, equals(0));

      expect(find.text('Status: Quarantined (Fail-Closed)'), findsOneWidget);
      expect(find.text('Data Quarantined – Compliance Failure'), findsOneWidget);

      final buttonWidget = tester.widget<ElevatedButton>(submitButton);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('Case 3: Server 500 / Null API Response / Timeout -> Purges volatile memory, locks button, sets Quarantined', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': null}), 500);
      });

      final apiService = ComplianceApiService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: LsaVerificationScreen(apiService: apiService),
        ),
      );
      await tester.pumpAndSettle();

      final consentField = find.widgetWithText(TextField, 'Parent Consent Code');
      await tester.enterText(consentField, 'PCC-2026-9901');
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(ElevatedButton, 'Verify & Submit');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Status: Quarantined (Fail-Closed)'), findsOneWidget);
      expect(find.text('Data Quarantined – Compliance Failure'), findsOneWidget);

      final consentFieldWidget = tester.widget<TextField>(consentField);
      expect(consentFieldWidget.controller?.text, isEmpty);

      final buttonWidget = tester.widget<ElevatedButton>(submitButton);
      expect(buttonWidget.onPressed, isNull);

      // Verify Reset Form button restores UI to Idle and unlocks submission
      final resetButton = find.text('Reset Form & Unlock Submission');
      expect(resetButton, findsOneWidget);
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      expect(find.text('Status: Idle'), findsOneWidget);
      final unlockedButton = tester.widget<ElevatedButton>(submitButton);
      expect(unlockedButton.onPressed, isNotNull);
    });

    testWidgets('Demo Presets: Selecting Case 1 tile loads valid submission state', (tester) async {
      await tester.pumpWidget(const HabotApp());
      await tester.pumpAndSettle();

      final case1Tile = find.text('Case 1');
      expect(case1Tile, findsOneWidget);
      await tester.ensureVisible(case1Tile);
      await tester.tap(case1Tile);
      await tester.pumpAndSettle();

      expect(find.text('PCC-2026-9901'), findsOneWidget);

      final submitButton = find.widgetWithText(ElevatedButton, 'Verify & Submit');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Status: Success'), findsOneWidget);
    });

    test('UI Friction Logging: Fires friction event when user stalls for > 5 seconds', () async {
      final loggedMessages = <String>[];
      final logger = FrictionLogger(
        fieldName: 'parent_consent_code',
        threshold: const Duration(seconds: 5),
        onLog: (msg) => loggedMessages.add(msg),
      );

      logger.onInteractionStart();
      expect(loggedMessages, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(loggedMessages, isEmpty);

      final shortLogger = FrictionLogger(
        fieldName: 'parent_consent_code',
        threshold: const Duration(milliseconds: 50),
        onLog: (msg) => loggedMessages.add(msg),
      );
      shortLogger.onInteractionStart();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(loggedMessages, isNotEmpty);
      expect(loggedMessages.first, contains('[UI_FRICTION_LOG]'));
      expect(loggedMessages.first, contains('Field: parent_consent_code'));
      expect(loggedMessages.first, contains('Hesitation Duration:'));

      logger.dispose();
      shortLogger.dispose();
    });
  });
}
