import Foundation

// JSON yedeğinden geri yükleme — web `yedekYukle` ile aynı dosya biçimlerini okur:
//  • yeni: { versiyon, tarih, veri: { kumesler, … }, sezonArsivi: [...] }
//  • eski: { kumesler, … } (kök düzeyde)
// Satırlar yeni kimlikle eklendiği için kümes/ünite kimlikleri eşlenir (kuluçka kaynakları, satış ürünleri,
// gider kümesi, ünite partilerinin kaynak kümesi) — web 7.21 öncesi bunu yapmıyordu.

public struct Yedek: Sendable {
    public var veri: Veri
    /// Sezon arşivi satırları (id, ad, tarih, veri).
    public var sezonlar: [JSONNesne]
    /// Yedeğin alındığı an (ISO metni), varsa.
    public var tarih: String?

    public var kayitSayisi: Int {
        veri.kumesler.count + veri.kuluckalar.count + veri.uniteler.count + veri.satislar.count + veri.giderler.count
    }

    public init(dosya: Data, bugun: String = Gun.bugun) throws {
        guard let kok = try? JSONDecoder().decode(JSON.self, from: dosya), kok.nesne != nil else {
            throw KuralHatasi("Geçersiz yedek dosyası!\nDosya JSON biçiminde değil.")
        }
        var ham: JSONNesne
        if let v = kok["veri"]?.nesne, v["kumesler"] != nil { ham = v }
        else if let v = kok.nesne, v["kumesler"] != nil { ham = v }
        else { throw KuralHatasi("Geçersiz yedek dosyası!\nKümes verisi bulunamadı.") }
        ham = metinTemizle(.nesne(ham)).nesne ?? [:]

        var v = Veri(bellek: ham)
        for i in v.kumesler.indices {
            if v.kumesler[i].ad.isEmpty { v.kumesler[i].ad = "Kümes \(i + 1)" }
            if (ham["kumesler"]?.dizi?[i]["tur"]?.string ?? "").isEmpty { v.kumesler[i].tur = "tavuk" }
        }
        for i in v.kuluckalar.indices {
            if v.kuluckalar[i].ad.isEmpty { v.kuluckalar[i].ad = "Kuluçka \(i + 1)" }
            if v.kuluckalar[i].baslangic.isEmpty { v.kuluckalar[i].baslangic = bugun }
            if v.kuluckalar[i].sure <= 0 { v.kuluckalar[i].sure = 21 }
        }
        for i in v.uniteler.indices where v.uniteler[i].ad.isEmpty { v.uniteler[i].ad = "Civciv Ünitesi" }
        for i in v.satislar.indices {
            if v.satislar[i].tarih.isEmpty { v.satislar[i].tarih = bugun }
            v.satislar[i].odenen = min(v.satislar[i].toplam, max(0, v.satislar[i].odenen))
        }
        for i in v.giderler.indices {
            if v.giderler[i].tarih.isEmpty { v.giderler[i].tarih = bugun }
            v.giderler[i].odenen = min(v.giderler[i].tutar, max(0, v.giderler[i].odenen))
        }
        veri = v
        let sz = kok["sezonArsivi"]?.dizi ?? []
        sezonlar = sz.compactMap { $0.nesne }.map { s in
            var s = s
            if (s.metin("id") ?? "").isEmpty { s["id"] = .metin(yeniKimlik()) }
            if s["veri"]?.nesne == nil { s["veri"] = .nesne([:]) }
            return s
        }
        tarih = kok["tarih"]?.string
    }
}

/// Web `metinTemizle`: metinlerdeki `<` / `>` → `‹` / `›` (web arayüzü innerHTML ile çizer).
public func metinTemizle(_ j: JSON) -> JSON {
    switch j {
    case .metin(let s): return .metin(s.replacingOccurrences(of: "<", with: "‹").replacingOccurrences(of: ">", with: "›"))
    case .dizi(let a): return .dizi(a.map(metinTemizle))
    case .nesne(let o): return .nesne(o.mapValues(metinTemizle))
    default: return j
    }
}

private func esle(_ h: inout JSONNesne, _ anahtar: String, _ harita: [String: String]) {
    if let eski = h.doluMetin(anahtar), let yeni = harita[eski] { h[anahtar] = .metin(yeni) }
}

extension Veri {
    /// Geri yüklemede kümesler yeni kimlik aldıktan sonra: kümese bakan tüm alanları çevirir.
    /// Gider kümesi eşlenemezse boşaltılır (DB'de yabancı anahtar; web ile aynı).
    public mutating func kumesKimlikleriniEsle(_ m: [String: String]) {
        for i in kuluckalar.indices {
            for j in kuluckalar[i].kaynaklar.indices { esle(&kuluckalar[i].kaynaklar[j].ham, "kumesId", m) }
            if var c = kuluckalar[i].cikim?.ham, let ks = c["kaynaklar"]?.dizi {
                c["kaynaklar"] = .dizi(ks.map { k in
                    guard var n = k.nesne else { return k }
                    esle(&n, "kumesId", m); return .nesne(n)
                })
                kuluckalar[i].cikim = Cikim(ham: c)
            }
        }
        for i in uniteler.indices {
            for j in uniteler[i].hareketler.indices { esle(&uniteler[i].hareketler[j].ham, "kaynakKumesId", m) }
        }
        for i in satislar.indices {
            for j in satislar[i].urunler.indices { esle(&satislar[i].urunler[j].ham, "kumesId", m) }
        }
        for i in giderler.indices { giderler[i].kumesId = giderler[i].kumesId.flatMap { m[$0] } }
    }

    /// Geri yüklemede üniteler yeni kimlik aldıktan sonra: satış ürünlerindeki ünite bağlantıları.
    public mutating func uniteKimlikleriniEsle(_ m: [String: String]) {
        for i in satislar.indices {
            for j in satislar[i].urunler.indices { esle(&satislar[i].urunler[j].ham, "uniteId", m) }
        }
    }
}
