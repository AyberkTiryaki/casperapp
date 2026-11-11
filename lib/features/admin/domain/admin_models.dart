import '../../profile/profile.dart';

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
  });
  final String id;
  final String fullName;
  final UserRole role;
  final bool isActive;

  factory ManagedUser.fromJson(Map<String, dynamic> j) => ManagedUser(
    id: j['id'] as String,
    fullName: (j['full_name'] as String?) ?? '',
    role: UserRole.fromString(j['role'] as String?),
    isActive: (j['is_active'] as bool?) ?? true,
  );
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    required this.createdAt,
    this.actorId,
    this.entityId,
    this.details = const {},
  });
  final int id;
  final String? actorId;
  final String action;
  final String entity;
  final String? entityId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: (j['id'] as num).toInt(),
    actorId: j['actor_id'] as String?,
    action: j['action'] as String,
    entity: (j['entity'] as String?) ?? '',
    entityId: j['entity_id'] as String?,
    details: j['details'] is Map
        ? Map<String, dynamic>.from(j['details'] as Map)
        : const {},
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

const auditActionLabels = <String, String>{
  'adjust_credits': 'Ders hakkı düzeltme',
  'assign_package': 'Paket atama',
  'cancel_class': 'Ders iptali',
  'cancel_reservation': 'Rezervasyon iptali',
  'create_referral': 'Referans ekleme',
  'decide_referral': 'Referans kararı',
  'end_freeze': 'Dondurma bitirme',
  'freeze_package': 'Paket dondurma',
  'set_active': 'Hesap durumu değişikliği',
  'set_no_show': 'Gelmedi işaretleme',
  'set_role': 'Rol değişikliği',
  'wallet_adjust': 'Cüzdan düzeltme',
  'wallet_reverse': 'Cüzdan ters kayıt',
  'wallet_topup': 'Bakiye yükleme',
};

String auditActionLabel(String action) => auditActionLabels[action] ?? action;

String _roleTr(Object? v) => UserRole.fromString(v?.toString()).label;

/// details JSON'unu okunabilir kısa bir metne çevirir.
String summarizeAuditDetails(String action, Map<String, dynamic> d) {
  if (d.isEmpty) return '';
  if (action == 'set_role') {
    return '${_roleTr(d['from'])} → ${_roleTr(d['to'])}';
  }
  if (action == 'set_active') {
    return d['is_active'] == true ? 'Aktif yapıldı' : 'Pasif yapıldı';
  }
  return d.entries.map((e) => '${e.key}: ${e.value}').join(', ');
}
