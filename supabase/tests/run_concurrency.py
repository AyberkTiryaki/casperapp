"""Gerçek eşzamanlılık testi (ROADMAP §13): aynı anda gelen istekler, ayrı bağlantılardan.

pgTAP tek transaction içinde çalıştığı için yarışı deneyemez. Bu betik bağlı projede
  1) test verisini kurar (commit edilir; yalnızca concur-*@example.invalid kullanıcıları),
  2) her senaryoda N ayrı `supabase db query --remote` sürecini aynı ana kilitleyip
     (veritabanı saatine göre pg_sleep) RPC'yi aynı anda çağırır,
  3) sonucu veritabanından doğrular,
  4) her durumda test verisini siler.

Senaryolar
  A  Son kontenjan: kapasitesi 1 olan derse 8 üye aynı anda  → tam 1 rezervasyon
  B  Tekrarlanan istek: aynı üye + aynı anahtar, 6 kez aynı anda → 1 rezervasyon, 1 hak düşümü
  C  Cüzdan yarışı: 100 TL bakiye, 30 TL ürün, 6 farklı satış aynı anda → 3 satış, 10 TL kalır
  D  Tekrarlanan satış: aynı anahtarla 5 satış aynı anda → 1 satış, 70 TL kalır

Kullanım (proje kökünden):  python supabase/tests/run_concurrency.py
Yalnızca dev/staging projesinde çalıştırın.
"""
import concurrent.futures
import datetime
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
BARRIER_SECONDS = 30  # CLI süreçlerinin hepsi bağlanana kadar beklenecek süre


def cid(name):
    return str(uuid.UUID(hashlib.md5(("casper-concur:" + name).encode()).hexdigest()))


RACE_MEMBERS = ["c_m%d" % i for i in range(1, 9)]
MEMBERS = RACE_MEMBERS + ["c_idem", "c_w1", "c_w2"]
STAFF = {"c_admin": "admin", "c_trainer": "trainer"}
ALL_USERS = list(STAFF) + MEMBERS


def find_cli():
    exe = shutil.which("supabase")
    if exe:
        return exe
    local = pathlib.Path(os.environ.get("LOCALAPPDATA", "")) / "supabase-cli" / "supabase.exe"
    if local.exists():
        return str(local)
    sys.exit("supabase CLI bulunamadı")


CLI = find_cli()
ENV = {k: v for k, v in os.environ.items() if k != "AI_AGENT" and not k.startswith("CLAUDE")}


def run_sql(sql, read_only=False):
    """(ok, rows | hata metni) döndürür."""
    args = [CLI, "db", "query", "--remote", "--agent", "no", "--output-format", "json"]
    args += ["--read-only"] if read_only else ["--yes"]
    proc = subprocess.run(args + [sql], cwd=str(ROOT), env=ENV,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out = proc.stdout.decode("utf-8", "replace").strip()
    err = proc.stderr.decode("utf-8", "replace")
    if proc.returncode != 0:
        m = re.search(r"ERROR:\s+\w+:\s+([^\\\n\"]+)", out + err)
        return False, (m.group(1).strip() if m else (out + err).strip()[-400:])
    try:
        return True, json.loads(out) if out else []
    except ValueError:
        return True, out


def must(sql, read_only=False):
    ok, res = run_sql(sql, read_only)
    if not ok:
        raise RuntimeError(res)
    return res


def ids_sql(names):
    return "array[%s]::uuid[]" % ",".join("'%s'" % cid(n) for n in names)


CLEANUP = """
do $c$
declare
  u uuid[] := {users};
  cats uuid[] := array['{cat}']::uuid[];
begin
  delete from public.credit_ledger where member_id = any(u);
  delete from public.reservations where member_id = any(u)
    or class_id in (select id from public.classes where category_id = any(cats));
  delete from public.classes where category_id = any(cats);
  delete from public.package_freezes where member_package_id in
    (select id from public.member_packages where member_id = any(u));
  update public.member_packages set replaced_by = null where member_id = any(u);
  delete from public.member_packages where member_id = any(u);
  delete from public.package_definitions where category_id = any(cats);
  delete from public.categories where id = any(cats);
  update public.wallet_ledger set reverses_entry_id = null where member_id = any(u);
  delete from public.wallet_ledger where member_id = any(u);
  delete from public.sales where member_id = any(u);
  delete from public.products where id = '{product}';
  delete from public.wallets where member_id = any(u);
  delete from public.audit_log where actor_id = any(u);
  delete from auth.users where id = any(u) and email like 'concur-%@example.invalid';
end
$c$;
""".format(users=ids_sql(ALL_USERS), cat=cid("cat"), product=cid("product"))


def setup_sql():
    users = []
    for name in ALL_USERS:
        users.append(
            "('00000000-0000-0000-0000-000000000000','{id}','authenticated','authenticated',"
            "'concur-{name}@example.invalid','',now(),"
            "'{{\"provider\":\"email\",\"providers\":[\"email\"]}}'::jsonb,"
            "jsonb_build_object('full_name','Eşz {name}','kvkk_accepted','true',"
            "'kvkk_version','concur-1'),now(),now())".format(id=cid(name), name=name))
    roles = "".join("update public.profiles set role = '%s' where id = '%s';\n" % (r, cid(n))
                    for n, r in STAFF.items())
    assigns = "".join(
        "perform public.assign_package('{m}', '{d}', '{k}');\n".format(
            m=cid(m), d=cid("def"), k=cid("pkg_" + m))
        for m in RACE_MEMBERS + ["c_idem"])
    return """
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values {users};
{roles}
insert into public.categories (id, name) values ('{cat}', 'Eşzamanlılık Testi');
insert into public.package_definitions (id, category_id, name, session_count, validity_days, price)
values ('{d}', '{cat}', 'Eşz 8', 8, 30, 1000);
insert into public.products (id, name, price) values ('{product}', 'Eşz Ürün', 30);
insert into public.classes (id, trainer_id, category_id, class_type, capacity, starts_at, ends_at, created_by)
values ('{c_race}', '{tr}', '{cat}', 'individual', 1, now() + interval '2 days', now() + interval '2 days 1 hour', '{tr}'),
       ('{c_idem}', '{tr}', '{cat}', 'group', 6, now() + interval '3 days', now() + interval '3 days 1 hour', '{tr}');
select set_config('request.jwt.claims', '{{"sub":"{admin}","role":"authenticated"}}', false);
do $s$
begin
{assigns}
  perform public.admin_wallet_topup('{w1}', 100, '{k_w1}');
  perform public.admin_wallet_topup('{w2}', 100, '{k_w2}');
end
$s$;
""".format(users=",\n".join(users), roles=roles, cat=cid("cat"), d=cid("def"),
           product=cid("product"), c_race=cid("class_race"), c_idem=cid("class_idem"),
           tr=cid("c_trainer"), admin=cid("c_admin"), assigns=assigns,
           w1=cid("c_w1"), w2=cid("c_w2"), k_w1=cid("topup_w1"), k_w2=cid("topup_w2"))


def worker_sql(actor, call, barrier):
    return """
select set_config('request.jwt.claims', '{{"sub":"{actor}","role":"authenticated"}}', false);
set role authenticated;
select pg_sleep(greatest(0, extract(epoch from (timestamptz '{barrier}' - clock_timestamp()))));
select clock_timestamp() as at, ({call}) is not null as ok;
""".format(actor=cid(actor), call=call, barrier=barrier)


def race(label, jobs):
    """jobs: [(actor, rpc çağrısı)]. Hepsini aynı anda çalıştırır, sonuçları döndürür."""
    db_now = must("select now() as t", read_only=True)[0]["t"]
    barrier = (datetime.datetime.strptime(db_now[:19], "%Y-%m-%d %H:%M:%S")
               + datetime.timedelta(seconds=BARRIER_SECONDS)).strftime("%Y-%m-%d %H:%M:%S+00")
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(jobs)) as pool:
        futures = [pool.submit(run_sql, worker_sql(a, c, barrier)) for a, c in jobs]
        results = [f.result() for f in futures]
    stamps = sorted(r[1][0]["at"] for r in results if r[0])
    ok = sum(1 for r in results if r[0])
    errors = sorted(r[1] for r in results if not r[0])
    spread = ""
    if len(stamps) > 1:
        def fmt(s):
            base, _, frac = re.match(r"([^.+]+)(\.(\d+))?", s).groups()
            return (datetime.datetime.strptime(base.strip(), "%Y-%m-%d %H:%M:%S")
                    + datetime.timedelta(microseconds=int((frac or "0").ljust(6, "0")[:6])))
        spread = " (başarılı çağrılar arası %.0f ms)" % (
            (fmt(stamps[-1]) - fmt(stamps[0])).total_seconds() * 1000)
    print("  %s: %d başarılı, hatalar: %s%s" % (label, ok, errors or "-", spread))
    return ok, errors


def check(name, cond, detail):
    print("  [%s] %s  %s" % ("OK " if cond else "HATA", name, detail))
    return cond


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print("Eski test verisi temizleniyor…")
    must(CLEANUP)
    passed = True
    try:
        print("Kurulum…")
        must(setup_sql())

        print("Senaryolar (her biri ~%ds bekleme ile aynı anda başlar):" % BARRIER_SECONDS)
        race("A son kontenjan", [
            (m, "public.book_class('%s', '%s')" % (cid("class_race"), cid("res_" + m)))
            for m in RACE_MEMBERS])
        race("B tekrarlanan rezervasyon", [
            ("c_idem", "public.book_class('%s', '%s')" % (cid("class_idem"), cid("res_idem")))
            for _ in range(6)])
        race("C cüzdan yarışı", [
            ("c_trainer", "public.sell_product('%s', '%s', 1, '%s')"
             % (cid("c_w1"), cid("product"), cid("sale_w1_%d" % i)))
            for i in range(6)])
        race("D tekrarlanan satış", [
            ("c_trainer", "public.sell_product('%s', '%s', 1, '%s')"
             % (cid("c_w2"), cid("product"), cid("sale_w2")))
            for _ in range(5)])

        v = must("""
select
  (select count(*) from public.reservations where class_id = '{cr}' and status = 'booked') race_res,
  (select booked_count from public.classes where id = '{cr}') race_count,
  (select count(*) from public.credit_ledger cl join public.reservations r on r.id = cl.reservation_id
     where r.class_id = '{cr}' and cl.entry_type = 'booking') race_ledger,
  (select count(*) from public.reservations where class_id = '{ci}') idem_res,
  (select remaining_credits from public.member_packages where member_id = '{mi}' and status = 'active') idem_left,
  (select count(*) from public.credit_ledger where member_id = '{mi}' and entry_type = 'booking') idem_ledger,
  (select balance from public.wallets where member_id = '{w1}') w1_balance,
  (select count(*) from public.sales where member_id = '{w1}') w1_sales,
  (select min(balance_after) from public.wallet_ledger where member_id = '{w1}') w1_min,
  (select sum(amount) from public.wallet_ledger where member_id = '{w1}') w1_sum,
  (select balance from public.wallets where member_id = '{w2}') w2_balance,
  (select count(*) from public.sales where member_id = '{w2}') w2_sales,
  (select count(*) from public.wallet_ledger where member_id = '{w2}' and entry_type = 'purchase') w2_ledger
""".format(cr=cid("class_race"), ci=cid("class_idem"), mi=cid("c_idem"),
           w1=cid("c_w1"), w2=cid("c_w2")), read_only=True)[0]

        print("Doğrulama:")
        num = lambda x: float(x) if x is not None else None
        passed &= check("A tek rezervasyon", v["race_res"] == 1 and v["race_count"] == 1
                        and v["race_ledger"] == 1,
                        "rezervasyon=%s booked_count=%s hak_düşümü=%s"
                        % (v["race_res"], v["race_count"], v["race_ledger"]))
        passed &= check("B tek kayıt, tek düşüm", v["idem_res"] == 1 and v["idem_left"] == 7
                        and v["idem_ledger"] == 1,
                        "rezervasyon=%s kalan_hak=%s düşüm=%s"
                        % (v["idem_res"], v["idem_left"], v["idem_ledger"]))
        passed &= check("C bakiye eksiye düşmedi", num(v["w1_balance"]) == 10 and v["w1_sales"] == 3
                        and num(v["w1_min"]) >= 0 and num(v["w1_sum"]) == num(v["w1_balance"]),
                        "bakiye=%s satış=%s en_düşük=%s hareket_toplamı=%s"
                        % (v["w1_balance"], v["w1_sales"], v["w1_min"], v["w1_sum"]))
        passed &= check("D satış bir kez işlendi", num(v["w2_balance"]) == 70 and v["w2_sales"] == 1
                        and v["w2_ledger"] == 1,
                        "bakiye=%s satış=%s hareket=%s"
                        % (v["w2_balance"], v["w2_sales"], v["w2_ledger"]))
    except Exception as e:  # noqa: BLE001
        print("HATA:", e)
        passed = False
    finally:
        print("Test verisi siliniyor…")
        must(CLEANUP)
        left = must("select count(*) n from auth.users where email like 'concur-%%@example.invalid'"
                    .replace("%%", "%"), read_only=True)[0]["n"]
        print("  kalan test kullanıcısı: %s" % left)
    print("SONUÇ:", "BAŞARILI" if passed else "BAŞARISIZ")
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
