import Foundation

/// Uygulamanın tüm verisi (web `D`). İş kuralları burada değer tipi üzerinde çalışır; uygulama katmanı
/// değişen kümes/ünite kimliklerini alıp yalnız onları kaydeder (çok cihazda başkasının değişikliğini ezmemek için).
public struct Veri: Equatable, Sendable {
    public var kumesler: [Kumes]
    public var kuluckalar: [Kulucka]
    public var uniteler: [Unite]
    public var satislar: [Satis]
    public var giderler: [Gider]

    public init(kumesler: [Kumes] = [], kuluckalar: [Kulucka] = [], uniteler: [Unite] = [],
                satislar: [Satis] = [], giderler: [Gider] = []) {
        self.kumesler = kumesler; self.kuluckalar = kuluckalar; self.uniteler = uniteler
        self.satislar = satislar; self.giderler = giderler
    }

    /// Web bellek biçiminden (sezon arşivi, JSON yedeği).
    public init(bellek v: JSONNesne) {
        func liste(_ k: String) -> [JSONNesne] { (v[k]?.dizi ?? []).compactMap { $0.nesne } }
        kumesler = liste("kumesler").map(Kumes.init(bellek:))
        kuluckalar = liste("kuluckalar").map(Kulucka.init(bellek:))
        uniteler = liste("civcivUniteleri").map(Unite.init(bellek:))
        satislar = liste("satislar").map(Satis.init(bellek:))
        giderler = liste("giderler").map(Gider.init(bellek:))
    }

    public var bellek: JSONNesne {
        ["kumesler": .dizi(kumesler.map { .nesne($0.bellek) }),
         "kuluckalar": .dizi(kuluckalar.map { .nesne($0.bellek) }),
         "civcivUniteleri": .dizi(uniteler.map { .nesne($0.bellek) }),
         "satislar": .dizi(satislar.map { .nesne($0.bellek) }),
         "giderler": .dizi(giderler.map { .nesne($0.bellek) })]
    }

    public func kumes(_ id: String?) -> Kumes? { kumesler.first { $0.id == id } }
    public func unite(_ id: String?) -> Unite? { uniteler.first { $0.id == id } }
    func kumesIndeks(_ id: String?) -> Int? { kumesler.firstIndex { $0.id == id } }
    func uniteIndeks(_ id: String?) -> Int? { uniteler.firstIndex { $0.id == id } }

    public var aktifKuluckalar: [Kulucka] { kuluckalar.filter { !$0.tamamlandi } }
    public var biten: [Kulucka] { kuluckalar.filter(\.tamamlandi) }
}

public struct KuralHatasi: LocalizedError, Equatable {
    public let mesaj: String
    public init(_ m: String) { mesaj = m }
    public var errorDescription: String? { mesaj }
}

/// Değişen kayıtlar (yalnız bunlar kaydedilir).
public struct Degisenler: Equatable, Sendable {
    public var kumesler: Set<String> = []
    public var uniteler: Set<String> = []
    public init() {}
    mutating func birlestir(_ d: Degisenler) {
        kumesler.formUnion(d.kumesler); uniteler.formUnion(d.uniteler)
    }
}

// MARK: - Kümes hayvan hareketleri

extension Veri {
    /// Hayvan ekle/çıkar (web `saveHA`). `irkId` nil → "Genel": ilk ırk (yoksa oluşturulur) ama
    /// çıkarmada stok kontrolü tüm kümesin toplamına göre yapılır (web ile aynı).
    public mutating func hayvanIslemi(kumesId: String, islem: Islem, irkId: String?, erkek: Int, disi: Int,
                                      not: String, dogumTarihi: String?, tarih: String = Gun.bugun) throws {
        guard let ki = kumesIndeks(kumesId) else { throw KuralHatasi("Kümes bulunamadı!") }
        guard erkek >= 0, disi >= 0, erkek + disi > 0 else { throw KuralHatasi("En az 1 hayvan girin!") }
        var k = kumesler[ki]
        if islem == .cikar {
            var mE = 0, mD = 0
            if let irkId, let ir = k.irklar.first(where: { $0.id == irkId }) {
                mE = ir.erkek; mD = ir.disi
            } else if irkId == nil {
                mE = k.erkek; mD = k.disi
            }
            if erkek > mE { throw KuralHatasi("Yeterli erkek yok!\nMevcut: \(mE), Çıkarılmak istenen: \(erkek)") }
            if disi > mD { throw KuralHatasi("Yeterli dişi yok!\nMevcut: \(mD), Çıkarılmak istenen: \(disi)") }
        }
        var irkAd = "Genel"
        var ii: Int?
        if let irkId {
            ii = k.irklar.firstIndex { $0.id == irkId }
        } else {
            if k.irklar.isEmpty { k.irklar = [Irk(ad: "Genel")] }
            ii = 0
        }
        if let ii {
            irkAd = k.irklar[ii].ad
            if islem == .ekle {
                k.irklar[ii].erkek += erkek; k.irklar[ii].disi += disi
            } else {
                k.irklar[ii].erkek = max(0, k.irklar[ii].erkek - erkek)
                k.irklar[ii].disi = max(0, k.irklar[ii].disi - disi)
            }
        }
        k.hareketler.append(KumesHareketi(islem: islem, erkek: erkek, disi: disi, not: not, tarih: tarih,
                                          irkAd: irkAd, dogumTarihi: islem == .ekle ? dogumTarihi : nil))
        kumesler[ki] = k
    }

    /// Hareketi siler ve etkisini geri alır (web `delKumesHareket`).
    public mutating func kumesHareketiSil(kumesId: String, indeks: Int) {
        guard let ki = kumesIndeks(kumesId), kumesler[ki].hareketler.indices.contains(indeks) else { return }
        var k = kumesler[ki]
        let hv = k.hareketler[indeks]
        if let ii = k.irklar.firstIndex(where: { $0.ad == hv.irkAd }) ?? (k.irklar.isEmpty ? nil : 0) {
            if hv.islem == .ekle {
                k.irklar[ii].erkek = max(0, k.irklar[ii].erkek - hv.erkek)
                k.irklar[ii].disi = max(0, k.irklar[ii].disi - hv.disi)
            } else {
                k.irklar[ii].erkek += hv.erkek
                k.irklar[ii].disi += hv.disi
            }
        }
        k.hareketler.remove(at: indeks)
        kumesler[ki] = k
    }
}

// MARK: - Civciv ünitesi / parti

extension Veri {
    /// Yeni parti ekle (web `saveUC` ekle).
    public mutating func partiEkle(uniteId: String, adet: Int, kaynak: String, not: String, tarih: String) throws {
        guard let ui = uniteIndeks(uniteId) else { throw KuralHatasi("Ünite bulunamadı!") }
        guard adet >= 1 else { throw KuralHatasi("Geçerli adet girin!") }
        let k = kaynak.trimmingCharacters(in: .whitespaces)
        uniteler[ui].hareketler.append(.parti(adet: adet, kaynak: k.isEmpty ? "Genel" : k, not: not, tarih: tarih))
        uniteler[ui].adet += adet
    }

    /// Partiden çıkar — ölüm/kayıp (web `savePartiCikar`).
    public mutating func partidenCikar(uniteId: String, partiId: String, adet: Int, not: String, tarih: String) throws {
        guard let ui = uniteIndeks(uniteId),
              let pi = uniteler[ui].hareketler.firstIndex(where: { $0.partiId == partiId && $0.islem == .ekle })
        else { throw KuralHatasi("Parti bulunamadı!") }
        let p = uniteler[ui].hareketler[pi]
        guard adet >= 1 else { throw KuralHatasi("Geçerli adet girin!") }
        guard adet <= p.kalan else {
            throw KuralHatasi("\"\(p.kaynak)\" partisinde yeterli stok yok!\nKalan: \(p.kalan), Çıkarılmak istenen: \(adet)")
        }
        uniteler[ui].hareketler[pi].kalan = max(0, p.kalan - adet)
        uniteler[ui].adet = max(0, uniteler[ui].adet - adet)
        let n = not.trimmingCharacters(in: .whitespaces)
        uniteler[ui].hareketler.append(.cikis(adet: adet, partiId: partiId, kaynak: p.kaynak,
                                              not: n.isEmpty ? "Ölüm/Kayıp" : n, tarih: tarih))
    }

    /// Partiyi düzenle (web `savePartiEdit`). Kalan > adet ise adet'e çekilir.
    public mutating func partiDuzenle(uniteId: String, partiId: String, kaynak: String, adet: Int, kalan: Int,
                                      tarih: String, not: String) throws {
        guard let ui = uniteIndeks(uniteId),
              let pi = uniteler[ui].hareketler.firstIndex(where: { $0.partiId == partiId && $0.islem == .ekle })
        else { throw KuralHatasi("Parti bulunamadı!") }
        let yeniKalan = min(max(0, kalan), max(0, adet))
        let fark = yeniKalan - uniteler[ui].hareketler[pi].kalan
        uniteler[ui].adet = max(0, uniteler[ui].adet + fark)
        let k = kaynak.trimmingCharacters(in: .whitespaces)
        uniteler[ui].hareketler[pi].kaynak = k.isEmpty ? "Genel" : k
        uniteler[ui].hareketler[pi].adet = max(0, adet)
        uniteler[ui].hareketler[pi].kalan = yeniKalan
        uniteler[ui].hareketler[pi].tarih = tarih
        uniteler[ui].hareketler[pi].not = not
    }

    /// Partiyi tamamen sil (web `silParti`).
    public mutating func partiSil(uniteId: String, partiId: String) {
        guard let ui = uniteIndeks(uniteId), let p = uniteler[ui].parti(partiId) else { return }
        uniteler[ui].adet = max(0, uniteler[ui].adet - p.kalan)
        uniteler[ui].hareketler.removeAll { $0.partiId == partiId }
    }

    /// Partiden kümese aktar (web `saveAktar`). `irkId` nil → `yeniIrkAdi` ile ırk (varsa aynı adlıya) eklenir.
    public mutating func kumeseAktar(uniteId: String, partiId: String, kumesId: String, irkId: String?, yeniIrkAdi: String?,
                                     erkek: Int, disi: Int, not: String, tarih: String) throws -> Degisenler {
        guard let ui = uniteIndeks(uniteId),
              let pi = uniteler[ui].hareketler.firstIndex(where: { $0.partiId == partiId && $0.islem == .ekle })
        else { throw KuralHatasi("Parti bulunamadı!") }
        guard let ki = kumesIndeks(kumesId) else { throw KuralHatasi("Kümes seçin!") }
        let p = uniteler[ui].hareketler[pi]
        let adet = erkek + disi
        guard erkek >= 0, disi >= 0, adet >= 1 else { throw KuralHatasi("En az 1 hayvan girin!") }
        guard adet <= p.kalan else {
            throw KuralHatasi("\"\(p.kaynak)\" partisinde yeterli stok yok!\nKalan: \(p.kalan), Aktarılmak istenen: \(adet)")
        }
        var k = kumesler[ki]
        let irkIndeks: Int
        if let irkId {
            guard let i = k.irklar.firstIndex(where: { $0.id == irkId }) else { throw KuralHatasi("Irk seçin!") }
            irkIndeks = i
        } else {
            let a = (yeniIrkAdi ?? "").trimmingCharacters(in: .whitespaces)
            let ad = a.isEmpty ? p.kaynak : a
            if let i = k.irklar.firstIndex(where: { $0.ad == ad }) { irkIndeks = i } else {
                k.irklar.append(Irk(ad: ad)); irkIndeks = k.irklar.count - 1
            }
        }
        let n = not.trimmingCharacters(in: .whitespaces)
        var u = uniteler[ui]
        u.hareketler[pi].kalan = max(0, p.kalan - adet)
        u.adet = max(0, u.adet - adet)
        u.hareketler.append(.cikis(adet: adet, partiId: partiId, kaynak: p.kaynak,
                                   not: n.isEmpty ? "Kümese aktarıldı: \(k.ad)" : n, tarih: tarih))
        k.irklar[irkIndeks].erkek += erkek
        k.irklar[irkIndeks].disi += disi
        k.hareketler.append(KumesHareketi(islem: .ekle, erkek: erkek, disi: disi,
                                          not: n.isEmpty ? "Üniteden aktarıldı: \(u.ad)" : n, tarih: tarih,
                                          irkAd: k.irklar[irkIndeks].ad, dogumTarihi: p.tarih))
        uniteler[ui] = u
        kumesler[ki] = k
        var d = Degisenler()
        d.uniteler.insert(u.id); d.kumesler.insert(k.id)
        return d
    }
}

// MARK: - Kuluçka çıkımı

extension Veri {
    /// Çıkım formu için kaynak satırları (web `openCik`). Daha önce çıkım girildiyse değerleri doldurur.
    public func cikimSatirlari(kuluckaId: String) -> [CikimKaynagi] {
        guard let k = kuluckalar.first(where: { $0.id == kuluckaId }) else { return [] }
        let kaynaklar = k.kaynaklar.isEmpty
            ? [YumurtaKaynagi(ham: ["id": .metin("genel"), "adet": .s(k.toplamYumurta), "aciklama": .metin("Genel")])]
            : k.kaynaklar
        var satirlar = kaynaklar.map { r -> CikimKaynagi in
            let ad = !r.aciklama.isEmpty ? r.aciklama : (kumes(r.kumesId)?.ad ?? "Kaynak")
            return CikimKaynagi(kaynakId: r.id, kumesId: r.kumesId, ad: ad, yumurta: r.adet)
        }
        if let eski = k.cikim?.kaynaklar {
            for (i, cr) in eski.enumerated() where i < satirlar.count {
                satirlar[i].civciv = cr.sayi("civciv"); satirlar[i].olu = cr.sayi("olu"); satirlar[i].bos = cr.sayi("bos")
            }
        }
        return satirlar
    }

    /// Çıkımı kaydeder (web `saveCik`): kuluçka tamamlanır; çıkan civcivler seçilen üniteye kaynak başına
    /// ayrı parti olarak eklenir. Değişen ünite kimliğini döner (yoksa nil).
    public mutating func cikimKaydet(kuluckaId: String, satirlar: [CikimKaynagi], tarih: String, not: String,
                                     uniteId: String?) throws -> String? {
        guard let ki = kuluckalar.firstIndex(where: { $0.id == kuluckaId }) else { throw KuralHatasi("Kuluçka bulunamadı!") }
        var k = kuluckalar[ki]
        guard !k.tamamlandi else { throw KuralHatasi("Bu kuluçkanın çıkımı zaten kaydedilmiş.") }
        guard !satirlar.isEmpty, satirlar.allSatisfy({
            $0.civciv >= 0 && $0.olu >= 0 && $0.bos >= 0 &&
            $0.civciv + $0.olu + $0.bos <= $0.yumurta
        }) else { throw KuralHatasi("Çıkım adetlerini kontrol edin.") }
        let tC = satirlar.reduce(0) { $0 + $1.civciv }
        let tO = satirlar.reduce(0) { $0 + $1.olu }
        let tB = satirlar.reduce(0) { $0 + $1.bos }
        k.durum = "tamamlandi"
        k.cikim = Cikim(ham: [
            "civciv": .s(tC), "olu": .s(tO), "bos": .s(tB), "tarih": .metin(tarih), "not": .metin(not),
            "kaynaklar": .dizi(satirlar.map { r in
                .nesne(["kaynakId": .metin(r.kaynakId), "ad": .metin(r.ad), "yumurta": .s(r.yumurta),
                        "civciv": .s(r.civciv), "olu": .s(r.olu), "bos": .s(r.bos)])
            })
        ])
        var degisen: String?
        if let uniteId, let ui = uniteIndeks(uniteId), tC > 0 {
            for r in satirlar where r.civciv > 0 {
                uniteler[ui].hareketler.append(.parti(adet: r.civciv, kaynak: r.ad, not: "Kuluçka: \(k.ad) — \(r.ad)",
                                                      tarih: tarih, kaynakKumesId: r.kumesId))
            }
            uniteler[ui].adet += tC
            degisen = uniteler[ui].id
        }
        kuluckalar[ki] = k
        return degisen
    }
}

// MARK: - Satış ve stok

extension Veri {
    /// Satışın stoğa etkisinin karşılaştırılabilir özeti (web `satisStokOzet`).
    public static func stokOzeti(_ urunler: [SatisUrunu]) -> [String] {
        urunler.compactMap { r in
            switch r.tip {
            case .hayvan: return "h|\(r.kumesId ?? "")|\(r.irkId ?? "")|\(r.erkekAdet)|\(r.disiAdet)"
            case .civciv: return "c|\(r.uniteId ?? "")|\(r.partiId ?? "")|\(r.adet)"
            default: return nil
            }
        }
    }

    /// Satışın düştüğü stoğu geri verir (web `satisStokIade`); DB'ye yazmaz.
    public mutating func satisStokIade(_ s: Satis, notOnEk: String, tarih: String = Gun.bugun) -> Degisenler {
        var d = Degisenler()
        for r in s.urunler {
            if r.tip == .hayvan, let kid = r.kumesId, let ki = kumesIndeks(kid), !kumesler[ki].irklar.isEmpty {
                var k = kumesler[ki]
                let ii = r.irkId.flatMap { id in k.irklar.firstIndex { $0.id == id } }
                if let ii {
                    k.irklar[ii].erkek += r.erkekAdet
                    k.irklar[ii].disi += r.disiAdet
                } else {
                    // Eski kayıt (ırk yok): ilk ırka
                    k.irklar[0].erkek += r.erkekAdet
                    k.irklar[0].disi += r.disiAdet
                }
                k.hareketler.append(KumesHareketi(islem: .ekle, erkek: r.erkekAdet, disi: r.disiAdet,
                                                  not: "\(notOnEk): \(s.musteriAdi)", tarih: tarih,
                                                  irkAd: ii.map { k.irklar[$0].ad } ?? "Genel"))
                kumesler[ki] = k
                d.kumesler.insert(k.id)
            } else if r.tip == .civciv, let uid = r.uniteId, let pid = r.partiId, let ui = uniteIndeks(uid) {
                var u = uniteler[ui]
                let pi = u.hareketler.firstIndex { $0.partiId == pid && $0.islem != .cikar }
                if let pi { u.hareketler[pi].kalan += r.adet }
                u.adet += r.adet
                // kalan: 0 → iade kaydı ayrı parti sayılmaz (web göçü kalan'sız "ekle"yi partiye çevirip
                // stoğu ikiye katlıyordu); stok, asıl partinin kalanına eklendi.
                let h = UniteHareketi(ham: ["islem": .metin("ekle"), "adet": .s(r.adet), "kalan": .s(0), "partiId": .metin(pid),
                                            "kaynak": .metin(pi.map { u.hareketler[$0].kaynak } ?? "Genel"),
                                            "not": .metin("\(notOnEk): \(s.musteriAdi)"), "tarih": .metin(tarih)])
                u.hareketler.append(h)
                uniteler[ui] = u
                d.uniteler.insert(u.id)
            }
        }
        return d
    }

    /// Satış ürünlerini doğrular (web `saveSat` kontrolleri). Düzenlemede eski satışın adetleri "kredi" sayılır.
    public func satisDogrula(_ urunler: [SatisUrunu], eski: Satis?) throws {
        guard !urunler.isEmpty else { throw KuralHatasi("En az bir ürün ekleyin!") }
        var krediH: [String: (e: Int, d: Int)] = [:]
        var krediP: [String: Int] = [:]
        var talepH: [String: (e: Int, d: Int)] = [:]
        var talepP: [String: Int] = [:]
        for r in eski?.urunler ?? [] {
            if r.tip == .hayvan {
                let a = "\(r.kumesId ?? "")|\(r.irkId ?? "")"
                let c = krediH[a] ?? (0, 0)
                krediH[a] = (c.e + r.erkekAdet, c.d + r.disiAdet)
            } else if r.tip == .civciv, let p = r.partiId {
                krediP["\(r.uniteId ?? "")|\(p)", default: 0] += r.adet
            }
        }
        for r in urunler {
            switch r.tip {
            case .hayvan:
                if r.erkekAdet < 0 || r.disiAdet < 0 { throw KuralHatasi("Hayvan adedi negatif olamaz!") }
                if r.erkekAdet + r.disiAdet == 0 { throw KuralHatasi("Hayvan satışı için erkek ve/veya dişi adet girin!") }
                if !r.fiyat.isFinite || r.fiyat <= 0 { throw KuralHatasi("Tüm ürünler için fiyat girin!") }
                guard let k = kumes(r.kumesId) else { throw KuralHatasi("Kümes bulunamadı!") }
                guard let irkId = r.irkId else { throw KuralHatasi("Hayvan satışı için bir ırk seçin!") }
                guard let ir = k.irklar.first(where: { $0.id == irkId }) else { throw KuralHatasi("Seçilen ırk bulunamadı!") }
                let kr = krediH["\(k.id)|\(ir.id)"] ?? (0, 0)
                let mE = ir.erkek + kr.e, mD = ir.disi + kr.d
                let anahtar = "\(k.id)|\(ir.id)"
                let onceki = talepH[anahtar] ?? (0, 0)
                let istenen = (e: onceki.e + r.erkekAdet, d: onceki.d + r.disiAdet)
                if istenen.e > mE { throw KuralHatasi("\"\(k.ad) / \(ir.ad)\" için yeterli erkek yok! (Mevcut: \(mE))") }
                if istenen.d > mD { throw KuralHatasi("\"\(k.ad) / \(ir.ad)\" için yeterli dişi yok! (Mevcut: \(mD))") }
                talepH[anahtar] = istenen
            case .civciv:
                if r.adet <= 0 || !r.fiyat.isFinite || r.fiyat <= 0 { throw KuralHatasi("Tüm ürünler için adet ve fiyat girin!") }
                guard let u = unite(r.uniteId) else { throw KuralHatasi("Civciv ünitesi bulunamadı!") }
                guard let pid = r.partiId else { throw KuralHatasi("\"\(u.ad)\" ünitesinden bir parti seçmelisiniz!") }
                guard let p = u.parti(pid) else { throw KuralHatasi("Seçilen parti bulunamadı!") }
                let anahtar = "\(u.id)|\(pid)"
                let m = p.kalan + (krediP[anahtar] ?? 0)
                talepP[anahtar, default: 0] += r.adet
                if talepP[anahtar, default: 0] > m {
                    throw KuralHatasi("\"\(p.kaynak)\" partisinde yeterli \(u.tip.ad.lowercased()) yok!\nKalan: \(m), Satılmak istenen: \(r.adet)")
                }
            default:
                if r.adet <= 0 || !r.fiyat.isFinite || r.fiyat <= 0 { throw KuralHatasi("Tüm ürünler için adet ve fiyat girin!") }
            }
        }
    }

    /// Satışı stoğa uygular (doğrulamadan sonra). Ürünlerin `adet`/`irkAd` alanları düzeltilir.
    /// Düzenlemede yalnız fiyat/müşteri/ödeme/not değiştiyse stoğa dokunmaz (web 7.15).
    public mutating func satisUygula(_ urunler: inout [SatisUrunu], eski: Satis?, musteri: String?,
                                     tarih: String) -> Degisenler {
        for i in urunler.indices where urunler[i].tip == .hayvan {
            urunler[i].adet = urunler[i].erkekAdet + urunler[i].disiAdet
        }
        var d = Degisenler()
        let mus = (musteri ?? "").isEmpty ? "Anonim" : musteri!
        if let eski, Veri.stokOzeti(eski.urunler) == Veri.stokOzeti(urunler) {
            for i in urunler.indices where i < eski.urunler.count {
                if urunler[i].irkAd == nil, let a = eski.urunler[i].irkAd { urunler[i].irkAd = a }
            }
            return d
        }
        if let eski { d.birlestir(satisStokIade(eski, notOnEk: "Satış düzenlendi")) }
        for i in urunler.indices {
            let r = urunler[i]
            if r.tip == .hayvan, let ki = kumesIndeks(r.kumesId) {
                var k = kumesler[ki]
                let ii = r.irkId.flatMap { id in k.irklar.firstIndex { $0.id == id } }
                if let ii {
                    k.irklar[ii].erkek = max(0, k.irklar[ii].erkek - r.erkekAdet)
                    k.irklar[ii].disi = max(0, k.irklar[ii].disi - r.disiAdet)
                    urunler[i].irkAd = k.irklar[ii].ad
                }
                k.hareketler.append(KumesHareketi(islem: .cikar, erkek: r.erkekAdet, disi: r.disiAdet,
                                                  not: "Satış: \(mus)", tarih: tarih,
                                                  irkAd: ii.map { k.irklar[$0].ad } ?? "Genel"))
                kumesler[ki] = k
                d.kumesler.insert(k.id)
            } else if r.tip == .civciv, let pid = r.partiId, let ui = uniteIndeks(r.uniteId) {
                var u = uniteler[ui]
                let pi = u.hareketler.firstIndex { $0.partiId == pid && $0.islem == .ekle }
                if let pi { u.hareketler[pi].kalan = max(0, u.hareketler[pi].kalan - r.adet) }
                u.adet = max(0, u.adet - r.adet)
                u.hareketler.append(.cikis(adet: r.adet, partiId: pid, kaynak: pi.map { u.hareketler[$0].kaynak } ?? "Genel",
                                           not: "Satış: \(mus)", tarih: tarih))
                uniteler[ui] = u
                d.uniteler.insert(u.id)
            }
        }
        return d
    }

    /// Kümeste tek ırk varsa onu seç (web `defIrk`).
    public func varsayilanIrk(_ kumesId: String?) -> String? {
        guard let k = kumes(kumesId), k.irklar.count == 1 else { return nil }
        return k.irklar[0].id
    }
}

// MARK: - Finans

public struct KisiAlacagi: Identifiable, Equatable, Sendable {
    public var id: String { ad }
    public let ad: String
    public let toplam: Double
    public let satislar: [Satis]
}

public struct FinansOzeti: Equatable, Sendable {
    public var gelir = 0.0, gider = 0.0, alacak = 0.0, borc = 0.0
    public var alacakKisi = 0, borcKayit = 0, satisSayisi = 0, giderSayisi = 0
    public var net: Double { gelir - gider }
}

extension Veri {
    /// `ay` "2026-11" ise yalnız o ay; nil ise tümü. Alacak/borç her zaman tüm kayıtlardan.
    public func finansOzeti(ay: String? = nil) -> FinansOzeti {
        var o = FinansOzeti()
        let s = satislar.filter { ay == nil || $0.tarih.hasPrefix(ay!) }
        let g = giderler.filter { ay == nil || $0.tarih.hasPrefix(ay!) }
        o.gelir = s.reduce(0) { $0 + $1.toplam }
        o.gider = g.reduce(0) { $0 + $1.tutar }
        o.satisSayisi = s.count; o.giderSayisi = g.count
        o.alacak = satislar.reduce(0) { $0 + $1.kalan }
        o.borc = giderler.reduce(0) { $0 + $1.kalan }
        o.alacakKisi = alacaklar.count
        o.borcKayit = giderler.filter { $0.kalan > 0 }.count
        return o
    }

    /// Ödenmemiş satışlar müşteriye göre, en çok alacak üstte (web `showAlacakDetay`).
    public var alacaklar: [KisiAlacagi] {
        var gruplar: [String: [Satis]] = [:]
        for s in satislar where s.kalan > 0 { gruplar[s.musteriAdi, default: []].append(s) }
        return gruplar.map { KisiAlacagi(ad: $0.key, toplam: $0.value.reduce(0) { $0 + $1.kalan }, satislar: $0.value) }
            .sorted { $0.toplam != $1.toplam ? $0.toplam > $1.toplam : $0.ad < $1.ad }
    }

    /// Kayıt bulunan aylar, yeniden eskiye ("2026-11").
    public var aylar: [String] {
        let t = Set((satislar.map(\.tarih) + giderler.map(\.tarih)).filter { $0.count >= 7 }.map { String($0.prefix(7)) })
        return t.sorted(by: >)
    }

    /// Yıl sonu: devreden alacak/borç kayıtları (web `yeniDonemeGec`).
    public func devredenler(alacak: Bool, borc: Bool, bugun: String = Gun.bugun) -> (satislar: [Satis], giderler: [Gider]) {
        let s = alacak ? satislar.filter { $0.kalan > 0 }.map { x -> Satis in
            let u = SatisUrunu(ham: ["tip": .metin("diger"), "ad": .metin("Önceki dönem alacağı"), "adet": .s(1), "fiyat": .s(x.kalan)])
            return Satis(musteri: (x.musteri ?? "") + " (önceki dönem)", tarih: bugun, urunler: [u], toplam: x.kalan,
                         odenen: 0, not: "Önceki dönemden devreden alacak. Orjinal tarih: \(x.tarih)")
        } : []
        let g = borc ? giderler.filter { $0.kalan > 0 }.map { x -> Gider in
            Gider(tur: x.tur, aciklama: (x.aciklama ?? "") + " (önceki dönem borç)", tutar: x.kalan, tarih: bugun,
                  kumesId: x.kumesId, odenen: 0)
        } : []
        return (s, g)
    }
}

// MARK: - Özet sayılar

public struct TurOzeti: Identifiable, Equatable, Sendable {
    public var id: String { tur.rawValue }
    public let tur: HayvanTuru
    public let kumes: Int
    public let hayvan: Int
}

extension Veri {
    public var toplamHayvan: Int { kumesler.reduce(0) { $0 + $1.toplam } }
    public var toplamErkek: Int { kumesler.reduce(0) { $0 + $1.erkek } }
    public var toplamDisi: Int { kumesler.reduce(0) { $0 + $1.disi } }
    public var toplamCivciv: Int { uniteler.filter { $0.tip == .civciv }.reduce(0) { $0 + $1.adet } }
    public var toplamYavruGuvercin: Int { uniteler.filter { $0.tip == .yavruGuvercin }.reduce(0) { $0 + $1.adet } }

    public var turOzetleri: [TurOzeti] {
        HayvanTuru.allCases.compactMap { t in
            let ks = kumesler.filter { $0.turu == t }
            return ks.isEmpty ? nil : TurOzeti(tur: t, kumes: ks.count, hayvan: ks.reduce(0) { $0 + $1.toplam })
        }
    }
}
