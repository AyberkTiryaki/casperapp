import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

const authRedirectUrl = 'caspertraining://auth-callback';

Future<void> initSupabase() => Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );

SupabaseClient get supabase => Supabase.instance.client;
