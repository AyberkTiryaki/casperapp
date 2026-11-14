# KVKK Notları — Hukuk Danışmanı ve Stüdyo İçin

Hazırlayan: Claude (taslak, 14.11.2026). Bu metinler hukuki görüş değildir. Yayından önce bir hukuk danışmanının gözden geçirmesi önerilir.

## Metinler

| Metin | Yeri | Sürüm |
|---|---|---|
| KVKK Aydınlatma Metni | Uygulama, kayıt ekranı (`lib/core/config/legal.dart` → `kvkkText`) | `2026-11-v2` |
| Sağlık verileri açık rıza metni | Aynı dosya (`healthConsentText`); kayıt ekranında ayrı, isteğe bağlı kutu + Profil ekranı | `2026-11-v1` |
| Gizlilik Politikası | `docs/GIZLILIK_POLITIKASI.md`, web'de yayımlanıp mağazaya URL olarak verilecek | — |

## Stüdyonun dolduracağı yerler

`[Stüdyonun ticari unvanı]`, `[Açık adres]`, `[E-posta adresi]`, `[Yayın tarihi]`. Bu bilgiler üç metinde de aynı olmalıdır.

## Danışmanın karar vermesi gereken konular

1. **Yurt dışına aktarım (md. 9):** Veritabanı Supabase üzerinde, AWS İsveç (eu-north-1) sunucularında. Bildirim için Google Firebase kullanılacak. Düzenli aktarım için Kurul'un **standart sözleşmesi** imzalanıp 5 iş günü içinde Kurum'a bildirilmesi mi, yoksa başka bir güvence mi uygun? Açık rıza md. 9'un yeni halinde yalnızca arızi aktarım için kullanılabildiğinden düzenli aktarımın tek dayanağı yapılmamalıdır.
2. **Sağlık verisi (md. 6):** Vücut ölçümleri özel nitelikli veri kabul edildi ve açık rızaya bağlandı. Kayıtta zorunlu alınan boy ve kilo (yol haritası §4) profil bilgisi olarak işleniyor, rıza metnine dahil edilmedi. Bunların da açık rızaya bağlanması gerekip gerekmediği danışmana sorulmalı.
3. **VERBİS kaydı:** Çalışan sayısı 50'den az ve yıllık mali bilanço eşiğin altındaysa, ana faaliyet özel nitelikli veri işlemek olmadığı sürece muafiyet olabilir. Stüdyonun durumu danışmanla teyit edilmeli.
4. **Saklama süreleri:** Mali kayıtlar için "10 yıla kadar" yazıldı (TTK md. 82, VUK). Kesin süre ve bir saklama-imha politikası danışmanla belirlenmeli.
5. **18 yaş altı üyeler:** Gizlilik politikası "18 yaş altı yalnızca veli onayıyla, Stüdyo tarafından açılır" diyor. Stüdyonun 18 yaş altı üyesi varsa bu süreç netleştirilmeli.

## Uygulamada yapılması gerekenler (yayından önce)

- [x] **Sağlık verileri açık rızası** (14.11.2026): kayıtta ayrı ve isteğe bağlı kutu, Profil'den verme / geri alma, rızasız ölçüm sunucuda engelli, geri alınca ölçümler silinir (K-09..K-12).
- [ ] Mevcut üyelerden yeni aydınlatma metni sürümü (`2026-11-v2`) onayı alınmalı (K-04, `accept_kvkk`).
- [ ] Hesap silme talebi onaylandığında silme veya anonimleştirme şu an yönetici tarafından elle yapılıyor. Bu işlem bir fonksiyonla otomatik hale getirilmeli ve mali kayıtlar anonim olarak korunmalı.
- [ ] Gizlilik politikası bir web adresinde yayımlanmalı (Play ve App Store zorunlu kılıyor). Google Play için ayrıca hesap silme talebinin web'den de yapılabildiği bir sayfa gerekiyor.
