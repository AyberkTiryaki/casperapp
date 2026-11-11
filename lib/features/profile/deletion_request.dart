import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

enum DeletionStatus {
  pending,
  processed,
  rejected;

  static DeletionStatus fromString(String? v) => switch (v) {
    'processed' => DeletionStatus.processed,
    'rejected' => DeletionStatus.rejected,
    _ => DeletionStatus.pending,
  };

  String get label => switch (this) {
    DeletionStatus.pending => 'Bekliyor',
    DeletionStatus.processed => 'Tamamlandı',
    DeletionStatus.rejected => 'Reddedildi',
  };
}

class DeletionRequest {
  const DeletionRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.requestedAt,
    this.note,
    this.processedAt,
  });

  final String id;
  final String userId;
  final DeletionStatus status;
  final String? note;
  final DateTime requestedAt;
  final DateTime? processedAt;

  factory DeletionRequest.fromJson(Map<String, dynamic> j) => DeletionRequest(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    status: DeletionStatus.fromString(j['status'] as String?),
    note: j['note'] as String?,
    requestedAt: DateTime.parse(j['requested_at'] as String),
    processedAt: j['processed_at'] == null
        ? null
        : DateTime.parse(j['processed_at'] as String),
  );
}

class KvkkConsent {
  const KvkkConsent({required this.version, required this.acceptedAt});
  final String version;
  final DateTime acceptedAt;
}

/// Profil formu: doğum tarihi boş bırakılabilir ama doluysa geçmişte olmalı.
String? validateOptionalBirthDate(DateTime? d, {DateTime? now}) {
  if (d == null) return null;
  final today = now ?? DateTime.now();
  if (!d.isBefore(DateTime(today.year, today.month, today.day)) ||
      d.year <= 1900) {
    return 'Doğum tarihi geçmişte olmalı.';
  }
  return null;
}

/// Bekleyen talep varken ikinci insert (unique ihlali, kod 23505).
bool isPendingDuplicate(Object e) =>
    e is PostgrestException && e.code == '23505';
