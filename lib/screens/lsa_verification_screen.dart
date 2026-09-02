import 'package:flutter/material.dart';
import '../models/verification_request.dart';
import '../models/verification_status.dart';
import '../services/compliance_api_service.dart';
import '../services/friction_logger.dart';
import '../core/lineage_exception.dart';
import '../widgets/status_banner.dart';
import '../widgets/lsa_header.dart';

class LsaVerificationScreen extends StatefulWidget {
  final ComplianceApiService? apiService;
  final String? initialPredecessorId;

  const LsaVerificationScreen({
    super.key,
    this.apiService,
    this.initialPredecessorId = 'PRED-9982-XYZ',
  });

  @override
  State<LsaVerificationScreen> createState() => _LsaVerificationScreenState();
}

class _LsaVerificationScreenState extends State<LsaVerificationScreen> {
  final _lsaIdController = TextEditingController(text: 'LSA-7049');
  final _consentCodeController = TextEditingController();
  final _consentFocusNode = FocusNode();

  late String? _predecessorId;
  bool _forceOrphanForTesting = false;
  bool _simulateServerErrorForTesting = false;
  int _selectedScenario = 1;

  VerificationStatus _status = VerificationStatus.idle;
  String? _statusMessage;

  late final ComplianceApiService _apiService;
  late final FrictionLogger _frictionLogger;

  @override
  void initState() {
    super.initState();
    _predecessorId = widget.initialPredecessorId;
    _apiService = widget.apiService ?? ComplianceApiService();
    _frictionLogger = FrictionLogger(
      fieldName: 'parent_consent_code',
      onLog: (logMessage) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'UI Friction Event Logged (>5s hesitation on parent_consent_code)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );
    _consentFocusNode.addListener(_handleFocusChange);
    // Note: we do NOT add a controller listener here because that fires
    // on programmatic text changes (e.g. _loadScenario). The timer resets
    // on actual user typing via onChanged on the TextField itself.
    _loadScenario(1);
  }

  void _handleFocusChange() {
    if (_consentFocusNode.hasFocus) {
      _frictionLogger.onInteractionStart();
    } else {
      _frictionLogger.onInteractionEnd();
    }
  }

  void _resetForm() {
    setState(() {
      _status = VerificationStatus.idle;
      _statusMessage = null;
      _loadScenario(_selectedScenario);
    });
  }

  void _loadScenario(int scenario) {
    setState(() {
      _selectedScenario = scenario;
      _status = VerificationStatus.idle;
      _statusMessage = null;
      if (scenario == 1) {
        _consentCodeController.text = 'PCC-2026-9901';
        _forceOrphanForTesting = false;
        _simulateServerErrorForTesting = false;
      } else if (scenario == 2) {
        _consentCodeController.text = 'PCC-2026-9901';
        _forceOrphanForTesting = true;
        _simulateServerErrorForTesting = false;
      } else if (scenario == 3) {
        _consentCodeController.text = 'PCC-2026-9901';
        _forceOrphanForTesting = false;
        _simulateServerErrorForTesting = true;
      }
    });
  }

  Future<void> _handleSubmit() async {
    _frictionLogger.onInteractionEnd();

    setState(() {
      _status = VerificationStatus.processing;
      _statusMessage = null;
    });

    final effectivePredecessorId = _forceOrphanForTesting ? null : _predecessorId;

    final request = VerificationRequest(
      predecessorId: effectivePredecessorId ?? '',
      lsaId: _lsaIdController.text.trim(),
      parentConsentCode: _consentCodeController.text.trim(),
      timestampUtc: DateTime.now().toUtc().toIso8601String(),
    );

    try {
      final result = await _apiService.submit(
        request,
        simulate500: _simulateServerErrorForTesting,
      );
      if (!mounted) return;
      if (result.quarantined) {
        _consentCodeController.clear();
        setState(() {
          _status = VerificationStatus.quarantined;
          _statusMessage = result.message ?? 'Data Quarantined – Compliance Failure';
        });
      } else {
        setState(() {
          _status = VerificationStatus.success;
          _statusMessage = result.message;
        });
      }
    } on LineageException {
      if (!mounted) return;
      _consentCodeController.clear();
      setState(() {
        _status = VerificationStatus.quarantined;
        _statusMessage = 'Data Quarantined – Compliance Failure';
      });
    }
  }

  bool get _isSubmitLocked =>
      _status == VerificationStatus.processing || _status == VerificationStatus.quarantined;

  @override
  void dispose() {
    _frictionLogger.dispose();
    _consentFocusNode.dispose();
    _lsaIdController.dispose();
    _consentCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Unified Modern Header (Replaces old duplicate AppBar)
              LsaHeader(
                showReset: _status != VerificationStatus.idle,
                onReset: _resetForm,
              ),
              const SizedBox(height: 14),

              // Main Form Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Field 1: lsa_id
                    TextField(
                      controller: _lsaIdController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'LSA ID',
                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF3B82F6)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Field 2: parent_consent_code
                    TextField(
                      controller: _consentCodeController,
                      focusNode: _consentFocusNode,
                      // Reset the friction timer on every real keystroke from the user.
                      // This is separate from the controller listener which also fires on programmatic changes.
                      onChanged: (_) => _frictionLogger.onInteractionStart(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Parent Consent Code',
                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        hintText: 'e.g. PCC-2026-9901',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.key_outlined, size: 18, color: Color(0xFF3B82F6)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Field 3: predecessor_id (System Lineage State)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _forceOrphanForTesting
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _forceOrphanForTesting
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _forceOrphanForTesting ? Icons.link_off_rounded : Icons.link_rounded,
                            color: _forceOrphanForTesting
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF2563EB),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _forceOrphanForTesting
                                  ? 'predecessor_id: null (Orphan)'
                                  : 'predecessor_id: ${_predecessorId ?? "null"}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: _forceOrphanForTesting
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _forceOrphanForTesting
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _forceOrphanForTesting ? 'ORPHAN' : 'BOUND',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _forceOrphanForTesting
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Status Banner
                    StatusBanner(
                      status: _status,
                      message: _statusMessage,
                    ),
                    const SizedBox(height: 14),

                    // Submit Action Button with modern gradient & glow
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: _isSubmitLocked
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isSubmitLocked
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitLocked ? null : _handleSubmit,
                        icon: _status == VerificationStatus.processing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          _status == VerificationStatus.processing
                              ? 'Verifying Compliance...'
                              : 'Verify & Submit',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    if (_status == VerificationStatus.quarantined ||
                        _status == VerificationStatus.success) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 38,
                        child: OutlinedButton.icon(
                          onPressed: _resetForm,
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text(
                            'Reset Form & Unlock Submission',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Bottom Test Case Selector with modern glowing pills
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text(
                          'Test Case Selector:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactCaseButton(
                            caseNum: 1,
                            title: 'Case 1',
                            subtitle: 'Valid (200)',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactCaseButton(
                            caseNum: 2,
                            title: 'Case 2',
                            subtitle: 'Orphan Lineage',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactCaseButton(
                            caseNum: 3,
                            title: 'Case 3',
                            subtitle: 'Server 500',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedScenario == 1
                          ? 'Case 1: Valid payload + metadata headers -> Verifies Success.'
                          : _selectedScenario == 2
                              ? 'Case 2: Null predecessor_id -> LineageException halts request.'
                              : 'Case 3: Server 500 / Null status -> Purges memory & locks submit.',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCaseButton({
    required int caseNum,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedScenario == caseNum;

    return InkWell(
      onTap: () => _loadScenario(caseNum),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFFBFDBFE) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}