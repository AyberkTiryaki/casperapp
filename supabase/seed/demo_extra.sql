-- Casper Training Studio — ek deneme verisi (demo.sql'den SONRA çalıştırılır).
-- Amaç: uygulamadaki her ekranda/tabloda denenecek bir şey olsun.
--   supabase db query --remote --yes -f supabase/seed/demo_extra.sql
-- Bir kez çalışır: daha önce çalıştıysa (uye1'in referansı varsa) hiçbir şey yapmaz.
-- Silmek için: supabase/seed/demo_cleanup.sql
--
-- Eklenenler
--   Ürünler      Elektrolit, Havlu, Pilates Çorabı, pasif bir kampanya ürünü
--   Satışlar     eğitmenlerden 4 satış; biri yönetici tarafından ters kayıtla düzeltilmiş
--   Cüzdan       uye6'ya +50 TL düzeltme (hediye)
--   Geçmiş       dün ve önceki gün dersleri: katıldı + gelmedi (no-show) örnekleri
--   Paketler     uye1-4 paketleri 10 gün önce başlamış gibi; uye6 paketi 2 gün içinde bitiyor;
--                uye5'in süresi dolmuş eski paketi; uye2'ye +1 telafi hakkı
--   Dondurma     uye3 paketi 3. günden 6. güne dondurulmuş
--   İptaller     uye2'nin zamanında iptal ettiği rezervasyon; yönetici tarafından iptal edilen ders
--   Referanslar  uye1→uye2 ve uye1→uye4 onaylı, uye2→uye3 beklemede, uye4→uye5 reddedildi
--   Hesap silme  uye5'in bekleyen talebi
--   Bildirimler  yukarıdaki olaylardan + zamanlanmış hatırlatma/bitiş uyarıları
-- device_tokens bilerek boş: gerçek telefon uygulamayı açınca kendi kaydını yazar.

create function pg_temp.sid(p text) returns uuid language sql immutable as
$$ select md5('casper-seed:' || p)::uuid $$;

create function pg_temp.as_user(p_handle text) returns void language sql as
$$ select set_config('request.jwt.claims',
     json_build_object('sub', pg_temp.sid(p_handle), 'role', 'authenticated')::text, true) $$;

-- Bugünden itibaren p_offset gün sonraki ilk pazar olmayan gün
create function pg_temp.wd(p_offset int) returns date language sql stable as $$
  select case when extract(isodow from d) = 7 then d + 1 else d end
  from (select (now() at time zone 'Europe/Istanbul')::date + p_offset as d) x
$$;

create function pg_temp.pkg(p_handle text) returns uuid language sql stable as $$
  select id from public.member_packages
  where member_id = pg_temp.sid(p_handle) and status = 'active' limit 1
$$;

create function pg_temp.cls(p_day date, p_slot text) returns uuid language sql immutable as
$$ select pg_temp.sid('class:' || p_day || ':' || p_slot) $$;

-- Geçmiş derse "yaşanmış" rezervasyon: kayıt + hak düşümü + kontenjan (book_class geçmişe izin vermez)
create function pg_temp.past_booking(p_handle text, p_class uuid) returns uuid language plpgsql as $$
declare
  v_pkg uuid := pg_temp.pkg(p_handle);
  v_res uuid;
  v_bal integer;
  v_at  timestamptz;
begin
  select starts_at - interval '1 day' into v_at from public.classes where id = p_class;
  insert into public.reservations
    (class_id, member_id, member_package_id, idempotency_key, booked_at, booked_by)
  values (p_class, pg_temp.sid(p_handle), v_pkg, pg_temp.sid('pastres:' || p_handle || p_class),
          v_at, pg_temp.sid(p_handle))
  returning id into v_res;
  update public.member_packages set remaining_credits = remaining_credits - 1
  where id = v_pkg returning remaining_credits into v_bal;
  insert into public.credit_ledger
    (member_package_id, member_id, entry_type, delta, balance_after, reservation_id, created_by, created_at)
  values (v_pkg, pg_temp.sid(p_handle), 'booking', -1, v_bal, v_res, pg_temp.sid(p_handle), v_at);
  update public.classes set booked_count = booked_count + 1 where id = p_class;
  return v_res;
end
$$;

do $extra$
declare
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_past1 uuid := pg_temp.sid('class:past1');
  v_past2 uuid := pg_temp.sid('class:past2');
  v_res   uuid;
  v_noshow uuid;
  v_entry bigint;
  v_ref   uuid;
begin
  if exists (select 1 from public.referrals where referrer_id = pg_temp.sid('uye1')) then
    raise notice 'demo_extra daha önce çalışmış, atlandı';
    return;
  end if;

  -- Paket geçmişi: 10 gün önce başlamış gibi; uye6 iki gün içinde bitiyor
  update public.member_packages
  set activated_at = activated_at - interval '10 days', ends_at = ends_at - interval '10 days',
      created_at = created_at - interval '10 days'
  where member_id in (pg_temp.sid('uye1'), pg_temp.sid('uye2'), pg_temp.sid('uye3'), pg_temp.sid('uye4'))
    and status = 'active';
  update public.member_packages
  set activated_at = activated_at - interval '28 days', ends_at = ends_at - interval '28 days',
      created_at = created_at - interval '28 days'
  where member_id = pg_temp.sid('uye6') and status = 'active';

  -- uye5: süresi dolmuş eski Pilates paketi (2 hakkı yanmış)
  insert into public.member_packages
    (id, member_id, definition_id, category_id, total_credits, remaining_credits, price_paid,
     list_price, activated_at, ends_at, status, closed_at, assigned_by, created_at)
  values (pg_temp.sid('pkg:uye5:old'), pg_temp.sid('uye5'), pg_temp.sid('def_p8'),
          pg_temp.sid('cat_pilates'), 8, 2, 2400, 2400, now() - interval '45 days',
          now() - interval '15 days', 'expired', now() - interval '15 days',
          pg_temp.sid('yonetici'), now() - interval '45 days');
  insert into public.credit_ledger
    (member_package_id, member_id, entry_type, delta, balance_after, note, created_by, created_at)
  values (pg_temp.sid('pkg:uye5:old'), pg_temp.sid('uye5'), 'grant', 8, 8, 'Paket atandı',
          pg_temp.sid('yonetici'), now() - interval '45 days'),
         (pg_temp.sid('pkg:uye5:old'), pg_temp.sid('uye5'), 'adjustment', -6, 2,
          'Eski sistemden aktarılan kullanım', pg_temp.sid('yonetici'), now() - interval '45 days');

  -- Geçmiş dersler: dün 10:00 Pilates (Ayşe), önceki gün 18:00 Fonksiyonel (Mert)
  insert into public.classes
    (id, trainer_id, category_id, class_type, capacity, title, starts_at, ends_at, created_by, created_at)
  values
    (v_past1, pg_temp.sid('egitmen1'), pg_temp.sid('cat_pilates'), 'group', 6, 'Sabah Pilates',
     ((v_today - 1) + time '10:00') at time zone 'Europe/Istanbul',
     ((v_today - 1) + time '10:50') at time zone 'Europe/Istanbul',
     pg_temp.sid('yonetici'), now() - interval '9 days'),
    (v_past2, pg_temp.sid('egitmen2'), pg_temp.sid('cat_fonk'), 'group', 6, 'Akşam Fonksiyonel',
     ((v_today - 2) + time '18:00') at time zone 'Europe/Istanbul',
     ((v_today - 2) + time '18:50') at time zone 'Europe/Istanbul',
     pg_temp.sid('yonetici'), now() - interval '9 days');
  perform pg_temp.past_booking('uye1', v_past1);
  v_noshow := pg_temp.past_booking('uye2', v_past1);
  perform pg_temp.past_booking('uye4', v_past2);
  perform pg_temp.past_booking('uye3', v_past2);

  -- Yönetici işlemleri
  perform pg_temp.as_user('yonetici');
  perform public.admin_set_no_show(v_noshow, true);
  perform public.admin_adjust_credits(pg_temp.pkg('uye2'), 1, 'Telafi dersi');
  perform public.freeze_package(pg_temp.pkg('uye3'), v_today + 3, v_today + 6, 'Tatil');

  -- Ürünler
  insert into public.products (id, name, price, is_active) values
    (pg_temp.sid('prd_elektrolit'), 'Elektrolit İçecek', 45, true),
    (pg_temp.sid('prd_havlu'),      'Havlu Kiralama',    15, true),
    (pg_temp.sid('prd_corap'),      'Pilates Çorabı',   150, true),
    (pg_temp.sid('prd_eski'),       'Yaz Kampanyası Paketi', 500, false)
  on conflict do nothing;

  -- Satışlar (eğitmenler) ve cüzdan düzeltmeleri (yönetici)
  perform pg_temp.as_user('egitmen1');
  perform public.sell_product(pg_temp.sid('uye1'), pg_temp.sid('prd_su'),  2, pg_temp.sid('sale:1'));
  perform public.sell_product(pg_temp.sid('uye1'), pg_temp.sid('prd_bar'), 1, pg_temp.sid('sale:2'));
  perform pg_temp.as_user('egitmen2');
  perform public.sell_product(pg_temp.sid('uye2'), pg_temp.sid('prd_shake'), 1, pg_temp.sid('sale:3'));

  perform pg_temp.as_user('yonetici');
  select id into v_entry from public.wallet_ledger where idempotency_key = pg_temp.sid('sale:2');
  perform public.admin_reverse_wallet_entry(v_entry, pg_temp.sid('rev:sale2'), 'Yanlış ürün girildi');
  perform public.admin_wallet_adjust(pg_temp.sid('uye6'), 50, 'Hoş geldin hediyesi', pg_temp.sid('adj:uye6'));

  perform pg_temp.as_user('egitmen3');
  perform public.sell_product(pg_temp.sid('uye6'), pg_temp.sid('prd_elektrolit'), 1, pg_temp.sid('sale:4'));

  -- Yaklaşan rezervasyonlar
  perform pg_temp.as_user('uye1');
  perform public.book_class(pg_temp.cls(pg_temp.wd(2), 'p10'), pg_temp.sid('res:x:uye1'));
  perform pg_temp.as_user('uye6');
  perform public.book_class(pg_temp.cls(pg_temp.wd(1), 'p19'), pg_temp.sid('res:x:uye6'));
  perform pg_temp.as_user('uye2');
  perform public.book_class(pg_temp.cls(pg_temp.wd(1), 'p12'), pg_temp.sid('res:x:uye2b'));

  -- Üyenin zamanında iptali (hak iade edilir)
  v_res := (public.book_class(pg_temp.cls(pg_temp.wd(2), 'p19'), pg_temp.sid('res:x:uye2'))).id;
  perform public.cancel_reservation(v_res, null, null);

  -- Yöneticinin ders iptali (hak iadeli)
  perform pg_temp.as_user('uye4');
  perform public.book_class(pg_temp.cls(pg_temp.wd(3), 'f18'), pg_temp.sid('res:x:uye4'));
  perform pg_temp.as_user('yonetici');
  perform public.cancel_class(pg_temp.cls(pg_temp.wd(3), 'f18'), true, 'Eğitmen raporlu');

  -- Referanslar
  perform public.admin_create_referral(pg_temp.sid('uye1'), pg_temp.sid('uye2'), 'Arkadaşı');
  perform public.admin_create_referral(pg_temp.sid('uye1'), pg_temp.sid('uye4'), null);
  perform public.admin_create_referral(pg_temp.sid('uye2'), pg_temp.sid('uye3'), null);
  perform public.admin_create_referral(pg_temp.sid('uye4'), pg_temp.sid('uye5'), null);
  for v_ref in select id from public.referrals
               where referred_id in (pg_temp.sid('uye2'), pg_temp.sid('uye4')) loop
    perform public.admin_decide_referral(v_ref, true, null);
  end loop;
  select id into v_ref from public.referrals where referred_id = pg_temp.sid('uye5');
  perform public.admin_decide_referral(v_ref, false, 'Aynı aileden, kampanya dışı');

  -- Hesap silme talebi (üye kendisi açar)
  insert into public.account_deletion_requests (user_id, note)
  values (pg_temp.sid('uye5'), 'Şehir değiştiriyorum');

  -- Zamanlanmış bildirimler (ders hatırlatması, paket bitiş uyarısı)
  perform private.enqueue_scheduled_notifications();
end
$extra$;

select
  (select count(*) from public.products)                  as urun,
  (select count(*) from public.sales)                     as satis,
  (select count(*) from public.wallet_ledger)             as cuzdan_hareketi,
  (select count(*) from public.package_freezes)           as dondurma,
  (select count(*) from public.reservations)              as rezervasyon,
  (select count(*) from public.classes where status = 'cancelled') as iptal_ders,
  (select count(*) from public.referrals)                 as referans,
  (select count(*) from public.account_deletion_requests) as silme_talebi,
  (select count(*) from public.notifications)             as bildirim,
  (select count(*) from public.audit_log)                 as denetim_kaydi;
