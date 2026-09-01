class VerificationRequest {
  final String predecessorId;
  final String lsaId;
  final String parentConsentCode;
  final String timestampUtc;

  const VerificationRequest({
    required this.predecessorId,
    required this.lsaId,
    required this.parentConsentCode,
    required this.timestampUtc,
  });

  Map<String, dynamic> toJson() => {
        'predecessor_id': predecessorId,
        'lsa_id': lsaId,
        'parent_consent_code': parentConsentCode,
        'timestamp_utc': timestampUtc,
      };
}