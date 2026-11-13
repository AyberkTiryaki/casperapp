"""pgTAP testlerini Docker olmadan, bağlı Supabase projesinde çalıştırır.

`supabase test db` uzak hedefte bile pg_prove için Docker ister. Bu betik onun yerine
`supabase db query --remote` kullanır (veritabanı şifresi gerekmez, CLI girişi yeter).

Güvenlik: her dosyanın sonundaki `finish(); rollback;` yerine her zaman hata fırlatan bir
blok konur. Hata, CLI sorguyu nasıl sararsa sarsın transaction'ı kesin olarak geri alır;
özet (plan / çalışan / başarısız) hata mesajında döner. Veritabanında iz kalmaz.

Kullanım (proje kökünden):  python supabase/tests/run_remote.py [dosya.test.sql ...]
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST_DIR = ROOT / "supabase" / "tests" / "database"
TAIL_IN = "select * from finish();\nrollback;"
TAIL_OUT = """
do $pgtap_end$
begin
  raise exception 'PGTAP_RESULT plan=% run=% failed=%',
    _get('plan'), _get('curr_test'), num_failed();
end
$pgtap_end$;
"""


def find_cli():
    exe = shutil.which("supabase")
    if exe:
        return exe
    local = pathlib.Path(os.environ.get("LOCALAPPDATA", "")) / "supabase-cli" / "supabase.exe"
    if local.exists():
        return str(local)
    sys.exit("supabase CLI bulunamadı")


def main():
    files = [pathlib.Path(a) for a in sys.argv[1:]] or sorted(TEST_DIR.glob("*.test.sql"))
    cli = find_cli()
    env = {k: v for k, v in os.environ.items() if k != "AI_AGENT" and not k.startswith("CLAUDE")}
    total_failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        for f in files:
            text = f.read_text(encoding="utf-8").rstrip()
            if not text.endswith(TAIL_IN):
                print("{}: beklenmeyen dosya sonu, atlandı".format(f.name))
                total_failed += 1
                continue
            prepared = pathlib.Path(tmp) / f.name
            prepared.write_text(text[: -len(TAIL_IN)] + TAIL_OUT, encoding="utf-8")
            proc = subprocess.run(
                [cli, "db", "query", "--remote", "--yes", "--agent", "no", "-f", str(prepared)],
                cwd=str(ROOT), env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            out = proc.stdout.decode("utf-8", "replace")
            m = re.search(r"PGTAP_RESULT plan=(\d+) run=(\d+) failed=(\d+)", out)
            if not m:
                err = re.search(r"ERROR:[^\"]*", out)
                print("{}: HATA {}".format(f.name, err.group(0) if err else out.strip()[-500:]))
                total_failed += 1
                continue
            plan, run, failed = (int(x) for x in m.groups())
            ok = failed == 0 and plan == run
            print("{}: {} plan={} run={} failed={}".format(
                f.name, "OK" if ok else "BAŞARISIZ", plan, run, failed))
            if not ok:
                total_failed += 1
    sys.exit(1 if total_failed else 0)


if __name__ == "__main__":
    main()
