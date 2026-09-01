import 'package:flutter/material.dart';
import '../models/verification_status.dart';

class StatusBanner extends StatelessWidget {
  final VerificationStatus status;
  final String? message;

  const StatusBanner({
    super.key,
    required this.status,
    this.message,
  });

  Color _backgroundColor(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.idle:
        return const Color(0xFFF8FAFC);
      case VerificationStatus.processing:
        return const Color(0xFFEFF6FF);
      case VerificationStatus.quarantined:
        return const Color(0xFFFEF2F2);
      case VerificationStatus.success:
        return const Color(0xFFF0FDF4);
    }
  }

  Color _borderColor(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.idle:
        return const Color(0xFFCBD5E1);
      case VerificationStatus.processing:
        return const Color(0xFF60A5FA);
      case VerificationStatus.quarantined:
        return const Color(0xFFF87171);
      case VerificationStatus.success:
        return const Color(0xFF4ADE80);
    }
  }

  Color _glowColor(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.idle:
        return Colors.transparent;
      case VerificationStatus.processing:
        return const Color(0xFF3B82F6).withValues(alpha: 0.15);
      case VerificationStatus.quarantined:
        return const Color(0xFFEF4444).withValues(alpha: 0.18);
      case VerificationStatus.success:
        return const Color(0xFF22C55E).withValues(alpha: 0.18);
    }
  }

  Color _primaryColor(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.idle:
        return const Color(0xFF475569);
      case VerificationStatus.processing:
        return const Color(0xFF1D4ED8);
      case VerificationStatus.quarantined:
        return const Color(0xFFB91C1C);
      case VerificationStatus.success:
        return const Color(0xFF15803D);
    }
  }

  IconData _iconFor(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.idle:
        return Icons.shield_outlined;
      case VerificationStatus.processing:
        return Icons.sync_rounded;
      case VerificationStatus.quarantined:
        return Icons.gpp_bad_rounded;
      case VerificationStatus.success:
        return Icons.verified_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primaryColor(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: _backgroundColor(status),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor(status), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _glowColor(status),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconFor(status), color: primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Status: ${status.label}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: primary,
                  ),
                ),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}