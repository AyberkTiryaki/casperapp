import '../../core/config/supabase.dart';
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
}
