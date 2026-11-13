-- supabase/seed/demo.sql ile eklenen deneme verisini siler (canlıya geçmeden önce).
--   supabase db query --remote --yes -f supabase/seed/demo_cleanup.sql
-- Yalnızca @casper.test hesaplarına ve demo.sql'in sabit kimlikli kayıtlarına dokunur.
-- Not: Gerçek üyeler deneme kategorilerinde paket/ders kullandıysa ilgili silmeler
-- yabancı anahtar hatasıyla durur; bu durumda veri kaybı olmaz, önce o kayıtlara bakın.

create function pg_temp.sid(p text) returns uuid language sql immutable as
$$ select md5('casper-seed:' || p)::uuid $$;

do $c$
declare
  u    uuid[] := array(select id from auth.users where email like '%@casper.test');
  -- 'Yoga': 13.11.2026'da uygulama akışı denenirken yönetici hesabıyla eklendi
  cats uuid[] := array[pg_temp.sid('cat_pilates'), pg_temp.sid('cat_fonk')]
                 || array(select id from public.categories where name = 'Yoga');
  prds uuid[] := array[pg_temp.sid('prd_su'), pg_temp.sid('prd_bar'), pg_temp.sid('prd_shake'),
                       pg_temp.sid('prd_elektrolit'), pg_temp.sid('prd_havlu'),
                       pg_temp.sid('prd_corap'), pg_temp.sid('prd_eski')];
begin
  delete from public.credit_ledger where member_id = any(u);
  delete from public.reservations where member_id = any(u)
    or class_id in (select id from public.classes where trainer_id = any(u));
  delete from public.classes where trainer_id = any(u);
  delete from public.package_freezes where member_package_id in
    (select id from public.member_packages where member_id = any(u));
  update public.member_packages set replaced_by = null where member_id = any(u);
  delete from public.member_packages where member_id = any(u);
  update public.wallet_ledger set reverses_entry_id = null where member_id = any(u);
  delete from public.wallet_ledger where member_id = any(u);
  delete from public.sales where member_id = any(u) or seller_id = any(u);
  delete from public.wallets where member_id = any(u);
  delete from public.audit_log where actor_id = any(u);
  delete from public.package_definitions where category_id = any(cats);
  delete from public.categories where id = any(cats);
  delete from public.products where id = any(prds);
  delete from auth.users where id = any(u);
end
$c$;

select count(*) as kalan_deneme_hesabi from auth.users where email like '%@casper.test';
