import Foundation

// Dışa aktarma: JSON yedeği ve Excel (CSV) raporu — web `yedekAl` / `excelAl` ile aynı biçim.

func csvSatir(_ alanlar: [String]) -> String {
    alanlar.map { s in
        (s.contains(",") || s.contains("\"") || s.contains("\n")) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }.joined(separator: ",")
}

private func iki(_ d: Double) -> String { String(format: "%.2f", d) }

public enum RaporTipi: String, CaseIterable, Identifiable, Sendable {
    case tumu, satislar, giderler, kumesler
    public var id: String { rawValue }
    public var ad: String {
        switch self {
        case .tumu: return "Tam rapor"
        case .satislar: return "Satışlar"
        case .giderler: return "Giderler"
        case .kumesler: return "Kümesler"
        }
    }
}

extension Veri {
    /// UTF-8 BOM'lu CSV (Excel Türkçe karakterleri doğru okusun). Dosya adı web ile aynı.
    public func csvRaporu(_ tip: RaporTipi, bugun: String = Gun.bugun) -> (dosya: String, icerik: String) {
        var c = ""
        if tip == .satislar || tip == .tumu {
            c += "SATISLAR\n" + csvSatir(["Tarih", "Musteri", "Urunler", "Toplam", "Odenen", "Kalan", "Not"]) + "\n"
            for s in satislar {
                let urunler = s.urunler.map { "\($0.adet)x \($0.ad.isEmpty ? $0.tip.rawValue : $0.ad)" }.joined(separator: " + ")
                c += csvSatir([s.tarih, s.musteriAdi, urunler, iki(s.toplam), iki(s.odenen), iki(s.kalan), s.not ?? ""]) + "\n"
            }
            c += "\n"
        }
        if tip == .giderler || tip == .tumu {
            c += "GIDERLER\n" + csvSatir(["Tarih", "Tur", "Aciklama", "Tutar", "Odenen", "Kalan", "Kümes"]) + "\n"
            let turL = ["yem": "Yem", "ilac": "Ilac", "hayvan": "Canli Hayvan", "ekipman": "Ekipman", "kulucka": "Kulucka",
                        "bakim": "Bakim", "enerji": "Enerji", "kumes": "Kumes", "diger": "Diger"]
            for g in giderler {
                c += csvSatir([g.tarih, turL[g.tur] ?? g.tur, g.aciklama ?? "", iki(g.tutar), iki(g.odenen), iki(g.kalan),
                               kumes(g.kumesId)?.ad ?? "Genel"]) + "\n"
            }
            c += "\n"
        }
        if tip == .kumesler || tip == .tumu {
            c += "KUMESLER\n" + csvSatir(["Kümes Adı", "Tur", "Irk/Grup", "Erkek", "Disi", "Toplam"]) + "\n"
            for k in kumesler {
                if k.irklar.isEmpty {
                    c += csvSatir([k.ad, k.tur, "Genel", "0", "0", "0"]) + "\n"
                } else {
                    for r in k.irklar {
                        c += csvSatir([k.ad, k.tur, r.ad.isEmpty ? "Genel" : r.ad, "\(r.erkek)", "\(r.disi)", "\(r.toplam)"]) + "\n"
                    }
                }
            }
            c += "\n"
        }
        var dosya = "kumespro_\(tip.rawValue)_\(bugun).csv"
        if tip == .tumu {
            let topG = satislar.reduce(0) { $0 + $1.toplam }
            let topOd = satislar.reduce(0) { $0 + min($1.toplam, $1.odenen) }
            let topAl = satislar.reduce(0) { $0 + $1.kalan }
            let topGid = giderler.reduce(0) { $0 + $1.tutar }
            let topGidOd = giderler.reduce(0) { $0 + min($1.tutar, $1.odenen) }
            let topBorc = giderler.reduce(0) { $0 + $1.kalan }
            c += "FINANSAL OZET\n" + csvSatir(["Kalem", "Tutar"]) + "\n"
            for (a, d) in [("Toplam Gelir", topG), ("Tahsil Edilen", topOd), ("Alacak", topAl), ("Toplam Gider", topGid),
                           ("Odenen Gider", topGidOd), ("Odenmemis Borc", topBorc), ("Net Kar/Zarar", topG - topGid)] {
                c += csvSatir([a, iki(d)]) + "\n"
            }
            dosya = "kumespro_tam_rapor_\(bugun).csv"
        }
        return (dosya, "\u{FEFF}" + c)
    }

    /// JSON yedeği (web `yedekAl`, versiyon 5.0-cloud). Web'deki "Yedek Yükle" bu dosyayı okuyabilir.
    public func yedekJSON(eposta: String?, sezonlar: [Sezon], simdi: Date = Date()) -> (dosya: String, veri: Data) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let kok: JSON = .nesne([
            "versiyon": .metin("5.0-cloud"),
            "tarih": .metin(iso.string(from: simdi)),
            "kullanici": .metin(eposta ?? ""),
            "veri": .nesne(bellek),
            "sezonArsivi": .dizi(sezonlar.map { .nesne($0.ham) })
        ])
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let veri = (try? e.encode(kok)) ?? Data()
        let c = Gun.takvim.dateComponents([.year, .month, .day, .hour, .minute], from: simdi)
        let dosya = String(format: "kumesPro_yedek_%04d%02d%02d_%02d%02d.json",
                           c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
        return (dosya, veri)
    }
}
