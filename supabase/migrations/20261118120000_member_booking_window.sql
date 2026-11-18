-- Üye rezervasyon penceresi (18.11.2026 kararı):
-- Üye kendisi için yalnızca bugünün ve takip eden 2 günün (Europe/Istanbul) derslerine
-- rezervasyon yapabilir. Yönetici üye adına rezervasyon yaparken bu sınır uygulanmaz.
-- book_class fonksiyonunu kopyalamamak için reservations tablosunda tetikleyiciyle denetlenir.

create or replace function private.enforce_member_booking_window()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_starts timestamptz;
  v_today  date := (now() at time zone 'Europe/Istanbul')::date;
begin
  -- Yalnızca üyenin kendi yaptığı rezervasyon (yönetici adına yapılan değil)
  if new.booked_by is distinct from new.member_id then
    return new;
  end if;
  select starts_at into v_starts from public.classes where id = new.class_id;
  if (v_starts at time zone 'Europe/Istanbul')::date > v_today + 2 then
    raise exception 'BOOKING_WINDOW_CLOSED' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists reservations_member_booking_window on public.reservations;
create trigger reservations_member_booking_window
  before insert on public.reservations
  for each row execute function private.enforce_member_booking_window();
