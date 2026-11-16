"""Gizlilik ve hesap silme sayfalarını üretir (GitHub Pages: gsenlik.github.io/casper-studio).

Kaynak: docs/GIZLILIK_POLITIKASI.md ve web/legal/hesap-silme.md. Çıktı: web/legal/site/.
Kullanım (proje kökünden):  python web/legal/build.py
Sonra site/ içeriğini casper-studio deposuna gönderin (bkz. docs/KURULUM.md, "Yasal sayfalar").
"""
import html
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "web" / "legal" / "site"
UPDATED = "16 Kasım 2026"

CSS = """
:root{--bg:#f3f6fd;--card:#fff;--ink:#0d1430;--muted:#5a6585;--blue:#1447c8;--line:#dce3f4}
@media (prefers-color-scheme:dark){:root{--bg:#0c1222;--card:#141d38;--ink:#eef2ff;--muted:#9aa8d0;--blue:#8ab0ff;--line:#2a3870}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);
font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
header{background:linear-gradient(135deg,#0b2370,#1447c8 55%,#2f6bff);color:#fff;padding:28px 16px}
header div,main{max-width:760px;margin:0 auto}
header b{display:block;font-size:13px;letter-spacing:.18em;opacity:.85}
header h1{margin:6px 0 0;font-size:28px;line-height:1.2}
main{padding:20px 16px 48px}
section.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:8px 22px 16px;margin:0 0 16px}
h2{font-size:19px;margin:18px 0 6px}a{color:var(--blue)}p,li{color:var(--ink)}
.meta{color:var(--muted);font-size:14px}ol,ul{padding-left:22px}
.box{border-left:4px solid var(--blue);padding:10px 14px;background:var(--card);border-radius:8px;margin:12px 0}
nav{font-size:14px;margin-bottom:16px}nav a{margin-right:14px}
"""


def inline(text: str) -> str:
    t = html.escape(text)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(https?://[^\s<]+)", r'<a href="\1">\1</a>', t)
    t = re.sub(r"([\w.+-]+@[\w-]+\.[\w.]+)", r'<a href="mailto:\1">\1</a>', t)
    return t


def md_to_html(md: str) -> str:
    out, para, lst = [], [], None

    def flush():
        nonlocal para, lst
        if para:
            out.append("<p>" + "<br>".join(inline(x) for x in para) + "</p>")
            para = []
        if lst:
            tag, items = lst
            out.append(f"<{tag}>" + "".join(f"<li>{inline(i)}</li>" for i in items) + f"</{tag}>")
            lst = None

    for raw in md.splitlines():
        line = raw.rstrip()
        if not line:
            flush()
            continue
        if line.startswith("## "):
            flush()
            out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("- "):
            if para:
                flush()
            if not lst or lst[0] != "ul":
                flush()
                lst = ("ul", [])
            lst[1].append(line[2:])
        elif re.match(r"^\d+\. ", line):
            if para:
                flush()
            if not lst or lst[0] != "ol":
                flush()
                lst = ("ol", [])
            lst[1].append(re.sub(r"^\d+\. ", "", line))
        else:
            if lst:
                flush()
            para.append(line)
    flush()
    return "\n".join(out)


def page(title: str, eyebrow: str, body: str) -> str:
    return f"""<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} · Casper Training Studio</title>
<style>{CSS}</style></head>
<body><header><div><b>{html.escape(eyebrow)}</b><h1>{html.escape(title)}</h1></div></header>
<main><nav><a href="./">Ana sayfa</a><a href="gizlilik.html">Gizlilik politikası</a><a href="hesap-silme.html">Hesap silme</a></nav>
<section class="card">{body}</section>
<p class="meta">Son güncelleme: {UPDATED}</p></main></body></html>
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    privacy = (ROOT / "docs" / "GIZLILIK_POLITIKASI.md").read_text(encoding="utf-8")
    privacy = "\n".join(
        l for l in privacy.splitlines() if not l.startswith("# ") and not l.startswith("Son güncelleme:")
    )
    (OUT / "gizlilik.html").write_text(
        page("Gizlilik Politikası", "CASPER TRAINING STUDIO", md_to_html(privacy)), encoding="utf-8")

    deletion = (ROOT / "web" / "legal" / "hesap-silme.md").read_text(encoding="utf-8")
    (OUT / "hesap-silme.html").write_text(
        page("Hesap Silme Talebi", "CASPER TRAINING STUDIO", md_to_html(deletion)), encoding="utf-8")

    index = md_to_html(
        "Casper Training Studio mobil uygulaması stüdyomuzun üyeleri, eğitmenleri ve yöneticileri içindir.\n\n"
        "- **Gizlilik politikası:** https://gsenlik.github.io/casper-studio/gizlilik.html\n"
        "- **Hesap silme talebi:** https://gsenlik.github.io/casper-studio/hesap-silme.html\n\n"
        "İletişim: caspertrainingstudio@gmail.com · Instagram: https://www.instagram.com/caspertrainingstudio/"
    )
    (OUT / "index.html").write_text(page("Casper Training Studio", "TEKİRDAĞ", index), encoding="utf-8")
    (OUT / ".nojekyll").write_text("", encoding="utf-8")
    print("site:", OUT)


if __name__ == "__main__":
    main()
