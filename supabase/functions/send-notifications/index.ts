// Casper Training Studio — bildirim gönderici (FCM HTTP v1).
//
// Zamanlanmış görev (pg_cron + pg_net) bu fonksiyonu birkaç dakikada bir çağırır.
// Kuyruktaki 'pending' bildirimleri claim_notifications ile sahiplenir, kullanıcının
// tüm cihazlarına gönderir ve sonucu complete_notification ile yazar.
//
// Gerekli gizli değerler (supabase secrets set ...):
//   FCM_SERVICE_ACCOUNT  Firebase servis hesabı JSON'u (tamamı, tek satır)
//   NOTIFY_CRON_SECRET   Çağıranın "x-cron-secret" başlığında göndermesi gereken değer
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından otomatik sağlanır.
// Service role anahtarı yalnızca burada, sunucuda kullanılır; mobil uygulamaya konmaz.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";

type Notification = {
  id: string;
  user_id: string;
  kind: string;
  title: string;
  body: string;
  payload: Record<string, unknown>;
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

function b64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function googleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key
    .replace(/-----[^-]+-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claim}`),
  );
  const jwt = `${header}.${claim}.${b64url(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`OAuth: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token as string;
}

// FCM data alanı yalnızca string değer kabul eder
function stringData(n: Notification): Record<string, string> {
  const out: Record<string, string> = { kind: n.kind, notification_id: n.id };
  for (const [k, v] of Object.entries(n.payload ?? {})) {
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("NOTIFY_CRON_SECRET");
  if (!secret || req.headers.get("x-cron-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }

  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!saRaw) return new Response("FCM_SERVICE_ACCOUNT missing", { status: 500 });
  const sa = JSON.parse(saRaw) as ServiceAccount;

  const { data: claimed, error } = await supabase.rpc("claim_notifications", {
    p_limit: 100,
  });
  if (error) return new Response(error.message, { status: 500 });
  const items = (claimed ?? []) as Notification[];
  if (items.length === 0) return Response.json({ sent: 0, failed: 0 });

  const userIds = [...new Set(items.map((n) => n.user_id))];
  const { data: tokens, error: tErr } = await supabase
    .from("device_tokens")
    .select("token, user_id")
    .in("user_id", userIds);
  if (tErr) return new Response(tErr.message, { status: 500 });

  const byUser = new Map<string, string[]>();
  for (const t of tokens ?? []) {
    byUser.set(t.user_id, [...(byUser.get(t.user_id) ?? []), t.token]);
  }

  const accessToken = await googleAccessToken(sa);
  const url =
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  const deadTokens: string[] = [];
  let sent = 0;
  let failed = 0;

  for (const n of items) {
    const userTokens = byUser.get(n.user_id) ?? [];
    // Cihazı olmayan kullanıcı: bildirim uygulama içi listede kalır, gönderilmiş sayılır
    let ok = userTokens.length === 0;
    let lastError: string | null = ok ? null : "";

    for (const token of userTokens) {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: n.title, body: n.body },
            data: stringData(n),
            android: { priority: "high" },
            apns: { payload: { aps: { sound: "default" } } },
          },
        }),
      });
      if (res.ok) {
        ok = true;
        continue;
      }
      const text = await res.text();
      lastError = `${res.status} ${text.slice(0, 300)}`;
      if (res.status === 404 || text.includes("UNREGISTERED")) {
        deadTokens.push(token);
      }
    }

    // Tüm cihazlar geçersizse yeniden denemenin anlamı yok
    if (!ok && userTokens.every((t) => deadTokens.includes(t))) ok = true;

    await supabase.rpc("complete_notification", {
      p_id: n.id,
      p_ok: ok,
      p_error: ok ? null : lastError,
    });
    ok ? sent++ : failed++;
  }

  if (deadTokens.length > 0) {
    await supabase.from("device_tokens").delete().in("token", deadTokens);
  }

  return Response.json({ sent, failed, removed_tokens: deadTokens.length });
});
