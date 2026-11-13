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
- `yedekYukle` → `GeriYukle.swift` (`Yedek`, kimlik eşleme) + `Depo.yedekYukle`. "Yedek öncesi" arşivi,
  yeni kayıtlar ve eski kayıtların silinmesi tek PostgreSQL transaction'ında tamamlanır. Sezon arşivi korunur.
- Satış iadesinde üniteye yazılan "ekle" kaydı `kalan: 0` taşır (web 7.22'den beri aynı).

## Derleme (yalnız Kamil onay verince)
```
gh workflow run ios-testflight.yml -R kamilsaim/kumespro-ios-yerel -f surum=8.0
```
Derleme no = 100 + çalıştırma×10 + deneme. 5 secret: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64,
DIST_CERT_P12_BASE64, DIST_CERT_PASSWORD.

## Durum (3 Kas 2026)
- 8.0 (111) ilk derleme; iPhone'da giriş (Apple/Google), widget, çıkım→ünite, satış→stok doğrulandı.
- Apple jeton iptali kuruldu: `apple-jeton` + `hesap-sil` + `kp_apple_jeton` (kaynaklar ana depoda `supabase/`, git dışı).

- 8.0 (133) TestFlight'ta: yeni uygulama ikonu + giriş/açılış logosu + kümes kartlarında tür resimleri (geçici kaynaklardan).
- macos-26 kuyruğu dolunca iş başlamadan ~15 dk sonra `cancelled` oluyor → `gh run rerun`.

## 13 Kasım 2026 yerel sürüm çalışması

- Ana ekran `yeni/ekran.png` referansına göre yeşil/krem düzene geçirildi. Dört sekme Ana Sayfa, Kümesler, Kayıtlar ve Raporlar.
- Hızlı işlemlerde Not Ekle yerine Kuluçka Başlat kullanılıyor. Logo ve uygulama ikonu tam `yeni/yenilogo.png` kaynağından üretildi.
- Geçersiz yedek listeleri reddediliyor. Aynı stok kaynağını kullanan satış satırlarının toplamı denetleniyor.
- Satış, çıkım, aktarım ve yedek işlemleri `kp_atomik_islem` ile tek transaction içinde yazılıyor.
  Beklenen eski satır karşılaştırması çakışmayı reddeder. Bekleyen istek cihazda korunur ve aynı kimlikle tekrar doğrulanır.
- Canlı kullanım öncesinde `supabase/migrations/20261113_kp_atomik_islem.sql` uygulanmalı.
  `supabase/tests/kp_atomik_islem_test.sql` transaction testlerini ROLLBACK içinde çalıştırır.
- Bu değişiklikler TestFlight'a yüklenmedi. GitHub doğrulama işleri ödeme/harcama limiti nedeniyle adımlar başlamadan durdu.
  Çekirdek testleri ve imzasız iOS simulator derlemesi bu nedenle henüz doğrulanamadı.

### Önceki açık işler
- Temiz logo (1024, çerçevesiz, yazısız) ve tür başına ≥300 px şeffaf PNG gelince Assets'teki geçici görselleri değiştir.
- `kp_apple_jeton`'a satır düştüğünü ve test Apple hesabıyla silmeyi doğrula.
- Formlarda kaydedilmemiş değişiklikte kaydırarak kapatma onayı (HIG).
- 8.0 (141) TestFlight'ta (4 Kas 2026): yedekten geri yükleme (Ayarlar) — iPhone'da denenecek.
- Mağaza metni, inceleme notu (yerel uygulama: WidgetKit, yerel bildirim, Apple ile Giriş, paylaşım menüsü), ekran görüntüleri.
