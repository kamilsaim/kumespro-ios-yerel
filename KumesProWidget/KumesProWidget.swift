//
//  KumesProWidget.swift — KümesPro kuluçka widget'ı (iOS, WidgetKit)
//
//  Android'deki KuluckaWidget.java'nın karşılığı: ana sayfadaki kuluçka
//  kartının (.hcard) kopyası.
//
//  Veri: web tarafı (app.html → widgetGuncelle) @capacitor/preferences ile
//  "kp_widget" anahtarına aktif kuluçkaları JSON olarak yazar:
//      {"k":[{"ad":"Sarı Kümes","bas":"2026-07-20","sure":21,"yum":24}, ...]}
//  Uygulamadaki AppDelegate bu değeri App Group'a ("group.com.kamilsaim.kumespro")
//  kopyalar; widget uzantısı yalnızca oradan okuyabilir.
//
//  Kalan gün / yüzde gösterim anında hesaplanır; zaman çizelgesi her gece
//  yarısı için ayrı giriş içerir → uygulama günlerce açılmasa da sayaç ilerler.
//
//  Boyutlar: küçük = kompakt özet, orta = Android'deki tam kart,
//  büyük = tam kart + diğer kuluçkaların listesi.
//

import WidgetKit
import SwiftUI

private let APP_GROUP = "group.com.kamilsaim.kumespro"
private let VERI_ANAHTARI = "kp_widget"

// MARK: - Veri

struct Kulucka: Identifiable {
    let id: Int
    let ad: String
    let sure: Int
    let yumurta: Int
    let gecen: Int
    let kalan: Int
    let yuzde: Int
    let baslangic: Date
    let cikim: Date
    let sepet: Date
}

enum KuluckaVeri {
    private static func sayi(_ v: Any?) -> Int {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) ?? 0 }
        return 0
    }

    /// Kayıtlı JSON'daki aktif kuluçkalar; çıkımı en yakın olan başta.
    static func aktifler(gun: Date) -> [Kulucka] {
        guard let ham = UserDefaults(suiteName: APP_GROUP)?.string(forKey: VERI_ANAHTARI),
              let data = ham.data(using: .utf8),
              let kok = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let dizi = kok["k"] as? [[String: Any]] else { return [] }

        let takvim = Calendar.current
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy-MM-dd"
        let bugun = takvim.startOfDay(for: gun)

        var sonuc: [Kulucka] = []
        for (i, o) in dizi.enumerated() {
            guard let bas = o["bas"] as? String, let bd = fmt.date(from: bas) else { continue }
            let sure = sayi(o["sure"])
            if sure <= 0 { continue }
            let basG = takvim.startOfDay(for: bd)
            guard let cikim = takvim.date(byAdding: .day, value: sure, to: basG),
                  let sepet = takvim.date(byAdding: .day, value: -3, to: cikim) else { continue }
            let kalan = takvim.dateComponents([.day], from: bugun, to: cikim).day ?? 0
            if kalan < 0 { continue } // çıkımı geçmiş (Android ile aynı davranış)
            let gecen = min(max(0, sure - kalan), sure)
            let yuzde = Int((Double(gecen) * 100.0 / Double(sure)).rounded())
            sonuc.append(Kulucka(
                id: i,
                ad: (o["ad"] as? String) ?? "Kuluçka",
                sure: sure, yumurta: sayi(o["yum"]),
                gecen: gecen, kalan: kalan, yuzde: yuzde,
                baslangic: basG, cikim: cikim, sepet: sepet))
        }
        return sonuc.sorted { $0.kalan < $1.kalan }
    }

    /// Galeride (widget eklerken) gösterilen örnek veri.
    static func ornek(gun: Date) -> [Kulucka] {
        let takvim = Calendar.current
        let bas = takvim.date(byAdding: .day, value: -14, to: takvim.startOfDay(for: gun)) ?? gun
        let cikim = takvim.date(byAdding: .day, value: 21, to: bas) ?? gun
        let sepet = takvim.date(byAdding: .day, value: -3, to: cikim) ?? gun
        return [
            Kulucka(id: 0, ad: "Brahma Kuluçkası", sure: 21, yumurta: 24, gecen: 14, kalan: 7,
                    yuzde: 67, baslangic: bas, cikim: cikim, sepet: sepet),
            Kulucka(id: 1, ad: "Güvercin", sure: 18, yumurta: 6, gecen: 6, kalan: 12,
                    yuzde: 33, baslangic: bas, cikim: cikim, sepet: sepet)
        ]
    }
}

// MARK: - Zaman çizelgesi

struct KuluckaGiris: TimelineEntry {
    let date: Date
    let liste: [Kulucka]
}

struct KuluckaSaglayici: TimelineProvider {
    func placeholder(in context: Context) -> KuluckaGiris {
        KuluckaGiris(date: Date(), liste: KuluckaVeri.ornek(gun: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (KuluckaGiris) -> Void) {
        let simdi = Date()
        let liste = KuluckaVeri.aktifler(gun: simdi)
        completion(KuluckaGiris(date: simdi,
                                liste: (context.isPreview && liste.isEmpty) ? KuluckaVeri.ornek(gun: simdi) : liste))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KuluckaGiris>) -> Void) {
        let simdi = Date()
        let takvim = Calendar.current
        var girisler = [KuluckaGiris(date: simdi, liste: KuluckaVeri.aktifler(gun: simdi))]
        // Sonraki 7 gece yarısı için hazır giriş: kalan gün kendiliğinden azalır
        let bugun = takvim.startOfDay(for: simdi)
        for g in 1...7 {
            if let gun = takvim.date(byAdding: .day, value: g, to: bugun) {
                girisler.append(KuluckaGiris(date: gun, liste: KuluckaVeri.aktifler(gun: gun)))
            }
        }
        completion(Timeline(entries: girisler, policy: .atEnd))
    }
}

// MARK: - Görünüm yardımcıları

extension Color {
    init(hex: UInt32, alfa: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alfa)
    }
}

enum Tema {
    static var arkaPlan: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x1A5C9E), Color(hex: 0x2E7FCC)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var ilerleme: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xE8711A), Color(hex: 0xF5B84A)],
                       startPoint: .leading, endPoint: .trailing)
    }
    static let rozetZemin = Color(hex: 0xFEF0E6)
    static let rozetYazi = Color(hex: 0xB8520E)
    static let soluk = Color.white.opacity(0.7)
    static let dahaSoluk = Color.white.opacity(0.55)
    static let cipZemin = Color.white.opacity(0.15)
}

func tarihYazi(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "tr_TR")
    f.dateFormat = "dd.MM.yyyy"
    return f.string(from: d)
}

func rozetYazi(_ kalan: Int) -> String {
    kalan == 0 ? "bugün" : (kalan == 1 ? "yarın" : "\(kalan) gün")
}

struct IlerlemeCubugu: View {
    let yuzde: Int
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.cipZemin)
                Capsule().fill(Tema.ilerleme)
                    .frame(width: max(0, g.size.width * CGFloat(min(yuzde, 100)) / 100))
            }
        }
        .frame(height: 7)
    }
}

struct Rozet: View {
    let yazi: String
    var body: some View {
        Text(yazi)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Tema.rozetYazi)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(Tema.rozetZemin))
    }
}

struct Cip: View {
    let yazi: String
    var body: some View {
        Text(yazi)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(Tema.cipZemin))
    }
}

struct BosGorunum: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🥚 Aktif kuluçka yok")
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            Text("Başlatmak için dokun")
                .font(.system(size: 11)).foregroundColor(Tema.soluk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Boyutlara göre görünümler

/// Küçük widget: kompakt özet (Android'deki kompakt düzen).
struct KucukGorunum: View {
    let k: Kulucka
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🥚 " + k.ad)
                .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
            if k.kalan == 0 {
                Text("BUGÜN\nÇIKIM!").font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
            } else if k.kalan == 1 {
                Text("YARIN\nÇIKIM").font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(k.kalan)").font(.system(size: 34, weight: .heavy)).foregroundColor(.white)
                    Text("gün kaldı").font(.system(size: 12, weight: .semibold)).foregroundColor(Tema.soluk)
                }
            }
            IlerlemeCubugu(yuzde: k.yuzde)
            Text(k.kalan == 3 ? "🧺 Sepete bugün!" : "🐣 " + tarihYazi(k.cikim))
                .font(.system(size: 11, weight: .semibold)).foregroundColor(Tema.soluk)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Orta widget: ana sayfadaki kuluçka kartının birebir karşılığı.
struct TamKart: View {
    let k: Kulucka
    let digerSayi: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(k.ad)
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Rozet(yazi: rozetYazi(k.kalan))
            }
            Text(altSatir)
                .font(.system(size: 11)).foregroundColor(Tema.soluk)
                .lineLimit(1).minimumScaleFactor(0.8)
            IlerlemeCubugu(yuzde: k.yuzde)
            HStack {
                Text("%\(k.yuzde) tamamlandı · \(k.gecen)/\(k.sure) gün geçti")
                    .font(.system(size: 11)).foregroundColor(Tema.dahaSoluk)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if digerSayi > 0 {
                    Text("+\(digerSayi) daha")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Tema.dahaSoluk)
                }
            }
            HStack(spacing: 6) {
                Cip(yazi: "🧺 Sepete: " + tarihYazi(k.sepet))
                Cip(yazi: "🐣 Çıkım: " + tarihYazi(k.cikim))
            }
        }
    }

    private var altSatir: String {
        var s = ""
        if k.yumurta > 0 { s += "🥚 \(k.yumurta) yumurta · " }
        return s + "📅 " + tarihYazi(k.baslangic) + " · ⏱ \(k.sure) gün"
    }
}

/// Büyük widget: tam kart + diğer kuluçkaların listesi.
struct BuyukGorunum: View {
    let liste: [Kulucka]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TamKart(k: liste[0], digerSayi: 0)
            if liste.count > 1 {
                Rectangle().fill(Tema.cipZemin).frame(height: 1)
                ForEach(Array(liste.dropFirst().prefix(4))) { k in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(k.ad)
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(rozetYazi(k.kalan))
                                .font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: 0xF5B84A))
                        }
                        IlerlemeCubugu(yuzde: k.yuzde)
                    }
                }
                if liste.count > 5 {
                    Text("+ \(liste.count - 5) kuluçka daha")
                        .font(.system(size: 11)).foregroundColor(Tema.dahaSoluk)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct KuluckaWidgetGorunum: View {
    @Environment(\.widgetFamily) var boyut
    let giris: KuluckaGiris

    var body: some View {
        icerik.widgetArkaPlan()
    }

    @ViewBuilder private var icerik: some View {
        if let ilk = giris.liste.first {
            switch boyut {
            case .systemSmall:
                KucukGorunum(k: ilk)
            case .systemLarge, .systemExtraLarge:
                BuyukGorunum(liste: giris.liste)
            default:
                TamKart(k: ilk, digerSayi: giris.liste.count - 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        } else {
            BosGorunum()
        }
    }
}

extension View {
    /// iOS 17+ widget arka plan API'si; daha eskide klasik arka plan + kenar boşluğu.
    @ViewBuilder func widgetArkaPlan() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { Tema.arkaPlan }
        } else {
            self.padding(14).background(Tema.arkaPlan)
        }
    }
}

// MARK: - Widget

struct KumesProWidget: Widget {
    let kind: String = "KumesProWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KuluckaSaglayici()) { giris in
            KuluckaWidgetGorunum(giris: giris)
        }
        .configurationDisplayName("Kuluçka Takibi")
        .description("En yakın çıkımı olan kuluçkanın kalan günü, ilerlemesi ve sepete alma / çıkım tarihleri.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
