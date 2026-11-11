-- Casper Training Studio — adım 7: bildirim kuyruğu.
--
-- Bildirimler public.notifications tablosuna 'pending' olarak yazılır; gönderimi
-- ayrı bir Edge Function (push servisi) yapar ve durumu 'sent' / 'failed' yapar.
-- dedupe_key benzersizdir: aynı bildirim asla iki kez kuyruğa girmez.
--
-- Türler:
--   booking_confirmed      rezervasyon yapıldı
--   reservation_cancelled  rezervasyon iptal edildi (üye, yönetici, ders iptali, dondurma)
--   class_reminder         ders ~3 saat sonra (2 saatlik iptal sınırından önce uyarır)
--   package_expiring       paketin bitmesine 3 gün veya daha az kaldı

create or replace function private.enqueue_notification(
  p_user_id uuid, p_kind text, p_title text, p_body text,
  p_payload jsonb, p_dedupe_key text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, kind, title, body, payload, dedupe_key)
  values (p_user_id, p_kind, p_title, p_body, coalesce(p_payload, '{}'::jsonb), p_dedupe_key)
  on conflict (dedupe_key) do nothing
$$;

create or replace function private.fmt_ist(p timestamptz)
returns text
language sql
immutable
set search_path = ''
as $$
  select to_char(p at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')
$$;

-- Rezervasyon olaylarından bildirim üret (aynı transaction içinde; geri alınırsa bildirim de gider)
create or replace function private.reservation_notify()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_when text;
  v_cat  text;
begin
  select private.fmt_ist(c.starts_at), cat.name into v_when, v_cat
  from public.classes c
  join public.categories cat on cat.id = c.category_id
  where c.id = new.class_id;

  if tg_op = 'INSERT' and new.status = 'booked'::public.reservation_status then
    perform private.enqueue_notification(
      new.member_id, 'booking_confirmed', 'Rezervasyon onaylandı',
      v_cat || ' dersi, ' || v_when || '. İyi antrenmanlar!',
      jsonb_build_object('reservation_id', new.id, 'class_id', new.class_id),
      'booking_confirmed:' || new.id);

  elsif tg_op = 'UPDATE'
        and old.status <> 'cancelled'::public.reservation_status
        and new.status = 'cancelled'::public.reservation_status then
    perform private.enqueue_notification(
      new.member_id, 'reservation_cancelled', 'Rezervasyon iptal edildi',
      v_cat || ' dersi, ' || v_when || '. '
        || case when new.cancelled_by is distinct from new.member_id
                     and new.cancel_reason is not null
                then 'Neden: ' || new.cancel_reason || '. ' else '' end
        || case when new.credit_refunded then 'Ders hakkınız iade edildi.'
                else 'Ders hakkı iade edilmedi.' end,
      jsonb_build_object('reservation_id', new.id, 'class_id', new.class_id,
                         'refunded', new.credit_refunded),
      'reservation_cancelled:' || new.id);
  end if;
  return null;
end;
$$;

drop trigger if exists reservations_notify on public.reservations;
create trigger reservations_notify
  after insert or update of status on public.reservations
  for each row execute function private.reservation_notify();

-- Zamanlanmış: ders hatırlatması ve paket bitiş uyarısı
create or replace function private.enqueue_scheduled_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_n     integer;
begin
  -- Ders 2–3 saat sonra: üye hâlâ iptal edebilecekken hatırlat
  insert into public.notifications (user_id, kind, title, body, payload, dedupe_key)
  select r.member_id, 'class_reminder', 'Ders hatırlatması',
         cat.name || ' dersiniz ' || private.fmt_ist(c.starts_at)
           || ' saatinde. Gelemeyecekseniz ders saatinden 2 saat öncesine kadar iptal edebilirsiniz.',
         jsonb_build_object('reservation_id', r.id, 'class_id', c.id),
         'class_reminder:' || r.id
  from public.reservations r
  join public.classes c on c.id = r.class_id
  join public.categories cat on cat.id = c.category_id
  where r.status = 'booked'::public.reservation_status
    and c.status = 'scheduled'::public.class_status
    and c.starts_at > now() + interval '2 hours'
    and c.starts_at <= now() + interval '3 hours'
  on conflict (dedupe_key) do nothing;
  get diagnostics v_n = row_count;
  v_count := v_count + v_n;

  -- Paket bitişine ≤ 3 gün. Bitiş tarihi değişirse (dondurma) yeni uyarı gidebilir.
  insert into public.notifications (user_id, kind, title, body, payload, dedupe_key)
  select mp.member_id, 'package_expiring', 'Paketiniz bitiyor',
         cat.name || ' paketiniz ' || private.fmt_ist(mp.ends_at) || ' tarihinde bitiyor. '
           || 'Kalan ders hakkı: ' || mp.remaining_credits || '.',
         jsonb_build_object('package_id', mp.id),
         'package_expiring:' || mp.id || ':' || (mp.ends_at at time zone 'Europe/Istanbul')::date
  from public.member_packages mp
  join public.categories cat on cat.id = mp.category_id
  where mp.status = 'active'::public.package_status
    and mp.ends_at > now()
    and mp.ends_at <= now() + interval '3 days'
  on conflict (dedupe_key) do nothing;
  get diagnostics v_n = row_count;
  v_count := v_count + v_n;

  return v_count;
end;
$$;

select cron.schedule(
  'enqueue-notifications',
  '*/10 * * * *',
  $cron$select private.enqueue_scheduled_notifications()$cron$
);

-- ---------------------------------------------------------------------------
-- Gönderici (Edge Function, service_role) için kuyruk RPC'leri.
-- claim: bekleyen bildirimleri sahiplenir; eşzamanlı iki çağrı aynı satırı almaz
-- (SKIP LOCKED). Yarım kalan sahiplenme 5 dakika sonra yeniden alınabilir.
-- ---------------------------------------------------------------------------
alter table public.notifications add column if not exists claimed_at timestamptz;
alter table public.notifications add column if not exists attempts integer not null default 0;
create index if not exists notifications_pending_idx
  on public.notifications (created_at) where status = 'pending';

create or replace function public.claim_notifications(p_limit integer default 100)
returns setof public.notifications
language sql
security definer
set search_path = ''
as $$
  update public.notifications n
  set claimed_at = now(), attempts = n.attempts + 1
  where n.id in (
    select id from public.notifications
    where status = 'pending'::public.notification_status
      and (claimed_at is null or claimed_at < now() - interval '5 minutes')
    order by created_at
    limit least(greatest(coalesce(p_limit, 100), 1), 500)
    for update skip locked)
  returning n.*
$$;

-- Gönderim sonucu. 3 denemede başarısızsa 'failed' kalır; aksi halde tekrar denenir.
create or replace function public.complete_notification(
  p_id uuid, p_ok boolean, p_error text default null)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.notifications
  set status = case when p_ok then 'sent'::public.notification_status
                    when attempts >= 3 then 'failed'::public.notification_status
                    else 'pending'::public.notification_status end,
      sent_at = case when p_ok then now() else sent_at end,
      error = case when p_ok then null else left(p_error, 500) end,
      claimed_at = case when p_ok or attempts >= 3 then claimed_at else null end
  where id = p_id and status = 'pending'::public.notification_status
$$;

-- ---------------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------------
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.user_role(), private.is_admin(), private.is_staff()
  to authenticated, service_role;

revoke all on function
  public.claim_notifications(integer),
  public.complete_notification(uuid, boolean, text)
from public, anon, authenticated;
grant execute on function
  public.claim_notifications(integer),
  public.complete_notification(uuid, boolean, text)
to service_role;
