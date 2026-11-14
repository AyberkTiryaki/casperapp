# KVKK Notları — Hukuk Danışmanı ve Stüdyo İçin

Hazırlayan: Claude (taslak, 14.11.2026). Bu metinler hukuki görüş değildir. Yayından önce bir hukuk danışmanının gözden geçirmesi önerilir.

## Metinler

| Metin | Yeri | Sürüm |
|---|---|---|
| KVKK Aydınlatma Metni | Uygulama, kayıt ekranı (`lib/core/config/legal.dart` → `kvkkText`) | `2026-11-v2` |
| Sağlık verileri açık rıza metni | Aynı dosya (`healthConsentText`), **henüz ekrana bağlı değil** | `2026-11-v1` |
| Gizlilik Politikası | `docs/GIZLILIK_POLITIKASI.md`, web'de yayımlanıp mağazaya URL olarak verilecek | — |

## Stüdyonun dolduracağı yerler

`[Stüdyonun ticari unvanı]`, `[Açık adres]`, `[E-posta adresi]`, `[Yayın tarihi]`. Bu bilgiler üç metinde de aynı olmalıdır.

## Danışmanın karar vermesi gereken konular

1. **Yurt dışına aktarım (md. 9):** Veritabanı Supabase üzerinde, AWS İsveç (eu-north-1) sunucularında. Bildirim için Google Firebase kullanılacak. Düzenli aktarım için Kurul'un **standart sözleşmesi** imzalanıp 5 iş günü içinde Kurum'a bildirilmesi mi, yoksa başka bir güvence mi uygun? Açık rıza md. 9'un yeni halinde yalnızca arızi aktarım için kullanılabildiğinden düzenli aktarımın tek dayanağı yapılmamalıdır.
2. **Sağlık verisi (md. 6):** Vücut ölçümleri özel nitelikli veri kabul edildi ve açık rızaya bağlandı. Boy ve kilonun da bu kapsamda değerlendirilip değerlendirilmeyeceği danışmana sorulmalı. Metin şu an boy ve kiloyu da rıza metnine dahil ediyor.
3. **VERBİS kaydı:** Çalışan sayısı 50'den az ve yıllık mali bilanço eşiğin altındaysa, ana faaliyet özel nitelikli veri işlemek olmadığı sürece muafiyet olabilir. Stüdyonun durumu danışmanla teyit edilmeli.
4. **Saklama süreleri:** Mali kayıtlar için "10 yıla kadar" yazıldı (TTK md. 82, VUK). Kesin süre ve bir saklama-imha politikası danışmanla belirlenmeli.
5. **18 yaş altı üyeler:** Gizlilik politikası "18 yaş altı yalnızca veli onayıyla, Stüdyo tarafından açılır" diyor. Stüdyonun 18 yaş altı üyesi varsa bu süreç netleştirilmeli.

## Uygulamada yapılması gerekenler (yayından önce)

- [ ] **Sağlık verileri açık rızası** kayıt ekranında aydınlatma onayından **ayrı ve isteğe bağlı** bir kutu olarak sorulmalı. Profilden sonradan verilip geri alınabilmeli. Rızası olmayan üyeye sunucu ölçüm kaydını reddetmeli. Rıza geri alınınca ölçümler silinmeli.
- [ ] Mevcut üyelerden yeni aydınlatma metni sürümü (`2026-11-v2`) onayı alınmalı (K-04, `accept_kvkk`).
- [ ] Hesap silme talebi onaylandığında silme veya anonimleştirme şu an yönetici tarafından elle yapılıyor. Bu işlem bir fonksiyonla otomatik hale getirilmeli ve mali kayıtlar anonim olarak korunmalı.
- [ ] Gizlilik politikası bir web adresinde yayımlanmalı (Play ve App Store zorunlu kılıyor). Google Play için ayrıca hesap silme talebinin web'den de yapılabildiği bir sayfa gerekiyor.
