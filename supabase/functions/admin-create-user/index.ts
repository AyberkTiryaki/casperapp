// Casper Training Studio — yöneticinin uygulama içinden kullanıcı (üye/eğitmen) açması.
//
// Çağıran kullanıcının JWT'si doğrulanır ve profilinin aktif 'admin' olduğu kontrol
// edilir. Hesap, e-postası doğrulanmış olarak ve yöneticinin belirlediği geçici
// şifreyle açılır; yönetici şifreyi kişiye iletir, kişi giriş yapıp şifresini değiştirir.
// Service role anahtarı yalnızca burada (sunucuda) kullanılır.
//
// İstek: { email, password, full_name, role?: 'member' | 'trainer' }
// Yanıt: { user_id } veya { error: <KOD> }

import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
};

function fail(code: string, status = 400) {
  return Response.json({ error: code }, { status, headers: cors });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail("METHOD_NOT_ALLOWED", 405);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: caller, error: authErr } = await admin.auth.getUser(jwt);
  if (authErr || !caller?.user) return fail("UNAUTHENTICATED", 401);

  const { data: me } = await admin
    .from("profiles")
    .select("role, is_active")
    .eq("id", caller.user.id)
    .maybeSingle();
  if (!me || me.role !== "admin" || !me.is_active) return fail("FORBIDDEN", 403);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail("INVALID_INPUT");
  }
  const email = String(body.email ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  const fullName = String(body.full_name ?? "").trim();
  const role = body.role === "trainer" ? "trainer" : "member";

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return fail("INVALID_EMAIL");
  if (password.length < 8 || password.length > 72) return fail("WEAK_PASSWORD");
  if (fullName.length < 2 || fullName.length > 120) return fail("INVALID_FULL_NAME");

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (createErr || !created?.user) {
    const msg = (createErr?.message ?? "").toLowerCase();
    if (msg.includes("already") || msg.includes("exists")) {
      return fail("EMAIL_ALREADY_REGISTERED", 409);
    }
    if (msg.includes("password")) return fail("WEAK_PASSWORD");
    return fail("CREATE_USER_FAILED", 500);
  }
  const userId = created.user.id;

  // Profil, auth tetikleyicisiyle 'member' olarak oluşur
  if (role === "trainer") {
    const { error } = await admin
      .from("profiles")
      .update({ role: "trainer" })
      .eq("id", userId);
    if (error) return fail("ROLE_UPDATE_FAILED", 500);
  }

  await admin.from("audit_log").insert({
    actor_id: caller.user.id,
    action: "admin_create_user",
    entity: "profiles",
    entity_id: userId,
    details: { email, role },
  });

  return Response.json({ user_id: userId }, { headers: cors });
});
