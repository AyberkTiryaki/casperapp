-- Ek test dersleri (play_review_reset.sql'den SONRA). Yönetici adına uygulamanın create_class RPC'siyle açılır.
--   supabase db query --remote --yes -f supabase/seed/test_classes_extra.sql
--
-- * Bu akşam (geçmişte kalmayanlar): 22:00 grup (Ayşe), 22:30 özel (Mert), 23:00 grup (Mert)
--   → hemen rezervasyon / iptal denemesi için
-- * Önümüzdeki 14 gün, hafta içi 14:00 grup dersi (Mert)
-- Aynı saatte eğitmenin başka dersi varsa (TRAINER_BUSY) o ders atlanır.

begin;

create function pg_temp.sid(p text) returns uuid language sql immutable as
$$ select md5('casper-review:' || p)::uuid $$;

do $x$
declare
  c_group uuid := (select id from public.categories where name = 'Atletik Performans Grup');
  c_ozel  uuid := (select id from public.categories where name = 'Özel Ders');
  v_ayse  uuid := pg_temp.sid('egitmen1');
  v_mert  uuid := pg_temp.sid('egitmen2');
  v_today date := (now() at time zone 'Europe/Istanbul')::date;
  v_n     integer := 0;
  r       record;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.sid('yonetici'), 'role', 'authenticated')::text, true);

  for r in
    select * from (values
      (c_group, 'group'::public.class_type, v_today + time '22:00', v_ayse),
      (c_ozel, 'individual'::public.class_type, v_today + time '22:30', v_mert),
      (c_group, 'group'::public.class_type, v_today + time '23:00', v_mert)
    ) t(cat, typ, at_local, trainer)
    union all
    select c_group, 'group'::public.class_type, d + time '14:00', v_mert
    from generate_series(v_today + 1, v_today + 14, interval '1 day') g(dd)
    cross join lateral (select dd::date as d) x
    where extract(isodow from d) between 1 and 5
  loop
    if (r.at_local at time zone 'Europe/Istanbul') <= now() + interval '5 minutes' then
      continue;
    end if;
    begin
      perform public.create_class(r.cat, r.typ, r.at_local at time zone 'Europe/Istanbul',
                                  60, null, r.trainer);
      v_n := v_n + 1;
    exception when others then
      if sqlerrm <> 'TRAINER_BUSY' then raise; end if;
    end;
  end loop;
  raise notice 'eklenen ders: %', v_n;
end
$x$;

select p.full_name as egitmen, count(*) as ders,
       count(*) filter (where (c.starts_at at time zone 'Europe/Istanbul')::date
                              = (now() at time zone 'Europe/Istanbul')::date) as bu_aksam
from public.classes c join public.profiles p on p.id = c.trainer_id
group by p.full_name order by 1;

commit;
