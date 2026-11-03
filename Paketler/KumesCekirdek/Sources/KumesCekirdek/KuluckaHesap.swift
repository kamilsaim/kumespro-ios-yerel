import Foundation

/// Kuluçkanın gün bazında durumu (web `kuCard`, `kuGecikme`).
public struct KuluckaDurumu: Equatable, Sendable {
    /// Geçen gün (0…sure).
    public let gecen: Int
    /// Kalan gün (0…sure).
    public let kalan: Int
    /// 0…100
    public let yuzde: Int
    /// >0 çıkım tarihi o kadar gün önce geçti, 0 bugün, <0 kalan gün.
    public let gecikme: Int
    public let baslangic: Date?
    public let cikim: Date?
    public let sepet: Date?

    public var gecikti: Bool { gecikme > 0 }
}

extension Kulucka {
    public func durum(bugun: Date = Date()) -> KuluckaDurumu {
        guard let bas = Gun.coz(baslangic), sure > 0 else {
            return KuluckaDurumu(gecen: 0, kalan: max(0, sure), yuzde: 0, gecikme: 0, baslangic: nil, cikim: nil, sepet: nil)
        }
        let fark = Gun.fark(bas, bugun)
        let gecen = min(max(0, fark), sure)
        let cikim = Gun.ekle(bas, gun: sure)
        return KuluckaDurumu(gecen: gecen, kalan: max(0, sure - gecen),
                             yuzde: Int((Double(gecen) / Double(sure) * 100).rounded()),
                             gecikme: fark - sure, baslangic: bas, cikim: cikim, sepet: Gun.ekle(cikim, gun: -3))
    }

    /// Çıkım verimi (%), yumurta yoksa nil.
    public var verim: Int? {
        guard let c = cikim, yumurta > 0 else { return nil }
        return Int((Double(c.civciv) / Double(yumurta) * 100).rounded())
    }

    /// Kaynakların kısa açıklaması: "Büyük kümes: 12 · Serbest: 6"
    public func kaynakOzeti(_ v: Veri) -> String {
        kaynaklar.map { r in
            let ad = !r.aciklama.isEmpty ? r.aciklama : (v.kumes(r.kumesId)?.ad ?? "Serbest")
            return "\(ad): \(r.adet)"
        }.joined(separator: " · ")
    }
}

/// Ana sayfa uyarıları (web `rDash` dAlert): önce gecikenler (en çok geciken üstte), sonra 0…3 gün kalanlar.
public struct KuluckaUyarisi: Identifiable, Equatable, Sendable {
    public var id: String { kuluckaId }
    public let kuluckaId: String
    public let ad: String
    /// Web ile aynı anlam: >0 gecikme günü, 0 bugün, <0 kalan gün.
    public let gecikme: Int

    public var baslik: String {
        if gecikme > 0 { return "\(ad) \(gecikme) gün gecikti" }
        if gecikme == 0 { return "\(ad) — bugün çıkım günü" }
        return "\(ad) — \(-gecikme) gün sonra çıkım"
    }
}

extension Veri {
    public func kuluckaUyarilari(bugun: Date = Date()) -> [KuluckaUyarisi] {
        let liste = aktifKuluckalar.map { KuluckaUyarisi(kuluckaId: $0.id, ad: $0.ad, gecikme: $0.durum(bugun: bugun).gecikme) }
        let geciken = liste.filter { $0.gecikme > 0 }.sorted { $0.gecikme > $1.gecikme }
        let yakin = liste.filter { $0.gecikme <= 0 && $0.gecikme >= -3 }.sorted { $0.gecikme > $1.gecikme }
        return geciken + yakin
    }

    /// Çıkımı en yakın aktif kuluçka (gecikmiş olanlar dahil, en eskisi önce).
    public func siradakiKulucka(bugun: Date = Date()) -> Kulucka? {
        aktifKuluckalar.filter { $0.sure > 0 && Gun.coz($0.baslangic) != nil }
            .min { $0.durum(bugun: bugun).gecikme > $1.durum(bugun: bugun).gecikme }
    }
}

extension Unite {
    /// Ağırlıklı ortalama yaş (gün), yalnız stoğu olan partiler (web `uniteOrtYas`).
    public func ortalamaYas(bugun: Date = Date()) -> Int? {
        let ps = hareketler.filter { $0.islem == .ekle && $0.tarih != nil && $0.kalan > 0 }
        guard !ps.isEmpty, adet > 0 else { return nil }
        var gunAdet = 0, top = 0
        for p in ps {
            gunAdet += (partiYasi(p.tarih, bugun: bugun) ?? 0) * p.kalan
            top += p.kalan
        }
        guard top > 0 else { return nil }
        return Int((Double(gunAdet) / Double(top)).rounded())
    }
}

// MARK: - Yerel bildirim planı (web `cikimBildirimleriKur` ile aynı kapsam)

public struct PlanliBildirim: Equatable, Sendable {
    public let kimlik: String
    public let baslik: String
    public let metin: String
    /// Yerel saat 08:00.
    public let zaman: Date
}

extension Veri {
    /// Her aktif kuluçka için sepete alma (çıkım−3), çıkım günü ve çıkım+2 "çıkım girilmedi" bildirimleri.
    /// Geçmiş zamanlar atlanır. iOS 64 bekleyen bildirim sınırı için en yakın 60 tanesi döner.
    public func bildirimPlani(simdi: Date = Date()) -> [PlanliBildirim] {
        var liste: [PlanliBildirim] = []
        for k in aktifKuluckalar where k.sure > 0 {
            guard let bas = Gun.coz(k.baslangic) else { continue }
            let cikim = Gun.ekle(bas, gun: k.sure)
            let adimlar: [(Date, String, String, String)] = [
                (Gun.ekle(cikim, gun: -3), "sepet", "🧺 Sepete alma zamanı", "\(k.ad) — 3 gün sonra çıkım, yumurtaları sepete alın."),
                (cikim, "cikim", "🐣 Çıkım günü!", "\(k.ad) — bugün çıkım günü, kuluçkayı kontrol edin."),
                (Gun.ekle(cikim, gun: 2), "gecikme", "⏰ Çıkım girilmedi",
                 "\(k.ad) — çıkım tarihi 2 gün önce geçti, çıkım sonucunu girmeyi unutmayın.")
            ]
            for (gun, tip, baslik, metin) in adimlar {
                guard let saat = Gun.takvim.date(bySettingHour: 8, minute: 0, second: 0, of: gun), saat > simdi else { continue }
                liste.append(PlanliBildirim(kimlik: "kp-\(k.id)-\(tip)", baslik: baslik, metin: metin, zaman: saat))
            }
        }
        return Array(liste.sorted { $0.zaman < $1.zaman }.prefix(60))
    }

    /// Widget verisi — web `widgetGuncelle` ile aynı biçim: {"k":[{"ad","bas","sure","yum"}]}
    public var widgetJSON: String {
        let k: [JSON] = aktifKuluckalar.filter { !$0.baslangic.isEmpty && $0.sure > 0 }.map {
            .nesne(["ad": .metin($0.ad), "bas": .metin($0.baslangic), "sure": .s($0.sure), "yum": .s($0.yumurta)])
        }
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        guard let d = try? e.encode(JSON.nesne(["k": .dizi(k)])) else { return "{\"k\":[]}" }
        return String(decoding: d, as: UTF8.self)
    }
}
