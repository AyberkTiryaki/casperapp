import '../../core/config/supabase.dart';
import '../../core/utils/formatters.dart';
import 'deletion_request.dart';
import 'profile.dart';

class ProfileRepository {
  /// Rol yalnızca `profiles` tablosundan okunur (metadata/JWT'den asla).
  Future<Profile?> fetchProfile(String userId) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  /// Yalnızca izin verilen sütunlar: ad, doğum tarihi, boy, güncel kilo.
  Future<void> updateProfile(
    String userId, {
    required String fullName,
    DateTime? birthDate,
    int? heightCm,
    double? weightKg,
  }) async {
    await supabase
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'birth_date': birthDate == null ? null : isoDate(birthDate),
          'height_cm': heightCm,
          'weight_kg': weightKg,
        })
        .eq('id', userId);
  }

  /// Son KVKK onayı (varsa).
  Future<KvkkConsent?> latestKvkk(String userId) async {
    final rows = await supabase
        .from('consents')
        .select('text_version, accepted_at')
        .eq('user_id', userId)
        .eq('consent_type', 'kvkk')
        .order('accepted_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return KvkkConsent(
      version: rows.first['text_version'] as String,
      acceptedAt: DateTime.parse(rows.first['accepted_at'] as String),
    );
  }

  Future<DeletionRequest?> pendingDeletionRequest(String userId) async {
    final row = await supabase
        .from('account_deletion_requests')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    return row == null ? null : DeletionRequest.fromJson(row);
  }

  /// Tek bekleyen talebe izin verilir; ikinci talepte 23505 döner.
  Future<void> requestDeletion(String userId, {String? note}) async {
    final n = (note ?? '').trim();
    await supabase.from('account_deletion_requests').insert({
      'user_id': userId,
      'note': n.isEmpty ? null : n,
    });
  }
}
