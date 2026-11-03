# KümesPro iOS — yerel SwiftUI uygulaması

Capacitor kabuğunun yerini alan yerel iPhone uygulaması. Web (GitHub Pages) ve Android değişmez;
aynı Supabase projesini (`pddkeomtxgygftuuwdzi`) ve aynı tabloları kullanır. Düzen Türbedar 3.0 ve
Sinerji 2.0'dan örnek alındı. Gizli depo: `kamilsaim/kumespro-ios-yerel`.

## Yapı
- `Paketler/KumesCekirdek` — yalnız Foundation: modeller (satır + web bellek biçimi), iş kuralları
  (stok, satış/iade, parti, aktarım, çıkım, finans, yıl sonu), CSV/JSON yedek, bildirim planı, widget JSON.
  Linux CI'da `swift test` (her push, `cekirdek-test.yml`).
- `KumesPro/` — SwiftUI uygulaması (Swift 5 dil kipi, iOS 17, yalnız iPhone, dikey).
- `KumesProWidget/` — ana ekran widget'ı (Capacitor dönemindeki kod, App Group `group.com.kamilsaim.kumespro`).
- `project.yml` — XcodeGen; Xcode projesi bulut Mac'te üretilir, elle tutulmaz.

## Web'den kopya kurallar (web değişince Swift'i de güncelle)
- `saveSat` / `satisStokIade` / `satisStokOzet` → `Veri.swift` (Satış ve stok)
- `saveHA`, `delKumesHareket` → `hayvanIslemi`, `kumesHareketiSil`
- parti işlemleri, `saveAktar`, `saveCik` → `Veri.swift`
- `dbYukle` ünite göçü → `Unite.init(satir:)`
- `cikimBildirimleriKur` (3 bildirim, 08:00) → `bildirimPlani()`; `widgetGuncelle` → `widgetJSON`
- `excelAl`, `yedekAl` (5.0-cloud) → `Disa.swift`
- Bilinçli fark: satış iadesinde ünitiye yazılan "ekle" kaydı `kalan: 0` taşır (web kalan'sız yazıyordu → web göçü
  bunu yeni parti sayıp stoğu ikiye katlayabiliyordu).

## Derleme (yalnız Kamil onay verince)
```
gh workflow run ios-testflight.yml -R kamilsaim/kumespro-ios-yerel -f surum=8.0
```
Derleme no = 100 + çalıştırma×10 + deneme. 5 secret: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64,
DIST_CERT_P12_BASE64, DIST_CERT_PASSWORD.

## Açık işler
- Apple jeton iptali (App Store 5.1.1(v)): uygulama girişte `apple-jeton` Edge Function'ına yetki kodunu
  gönderiyor; sunucu tarafı (fonksiyon + tablo + `hesap-sil`'de iptal) henüz kurulmadı.
- Yedek geri yükleme yalnız web'de.
