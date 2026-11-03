import Foundation

// Modeller iki biçimde okunur/yazılır:
//  • satır  — Supabase tablo satırı (not_, toplam_yumurta, kumes_id; ünitede ilk hareket {_meta, tip})
//  • bellek — web'in `D` nesnesindeki biçim (not, toplamYumurta, kumesId, tip). Sezon arşivi ve JSON
//             yedeği bu biçimde tutulur; web ile aynı dosya/arşiv okunabilsin diye birebir korunur.
// JSONB içindeki öğeler (`ham`) tanınmayan alanlarıyla birlikte saklanır.

// MARK: - Türler

public enum HayvanTuru: String, CaseIterable, Identifiable, Sendable {
    case tavuk, guvercin, hindi, kaz, bildircin, keklik, tavus, karisik, diger
    public var id: String { rawValue }

    public var ad: String {
        switch self {
        case .guvercin: return "Güvercin"
        case .tavuk: return "Tavuk"
        case .hindi: return "Hindi"
        case .kaz: return "Kaz/Ördek"
        case .karisik: return "Karışık"
        case .bildircin: return "Bıldırcın"
        case .keklik: return "Keklik"
        case .tavus: return "Tavus Kuşu"
        case .diger: return "Diğer"
        }
    }

    public static func coz(_ s: String?) -> HayvanTuru { HayvanTuru(rawValue: s ?? "") ?? .diger }
}

public enum GiderTuru: String, CaseIterable, Identifiable, Sendable {
    case yem, ilac, hayvan, ekipman, kulucka, bakim, enerji, kumes, diger
    public var id: String { rawValue }

    public var ad: String {
        switch self {
        case .yem: return "Yem"
        case .ilac: return "İlaç"
        case .hayvan: return "Canlı Hayvan"
        case .ekipman: return "Ekipman"
        case .kulucka: return "Kuluçka"
        case .bakim: return "Bakım"
        case .enerji: return "Enerji"
        case .kumes: return "Kümes"
        case .diger: return "Diğer"
        }
    }

    public static func coz(_ s: String?) -> GiderTuru { GiderTuru(rawValue: s ?? "") ?? .diger }
}

public enum UrunTipi: String, CaseIterable, Identifiable, Sendable {
    case hayvan, civciv, yumurta, diger
    public var id: String { rawValue }
    public var ad: String {
        switch self {
        case .hayvan: return "Hayvan"
        case .civciv: return "Civciv"
        case .yumurta: return "Yumurta"
        case .diger: return "Diğer"
        }
    }
}

public enum UniteTipi: String, CaseIterable, Identifiable, Sendable {
    case civciv
    case yavruGuvercin = "yavru_guvercin"
    public var id: String { rawValue }
    public var ad: String { self == .yavruGuvercin ? "Yavru Güvercin" : "Civciv" }
}

// MARK: - Kümes

public struct Irk: Identifiable, Equatable, Sendable {
    public var ham: JSONNesne
    public var id: String { get { ham.metin("id") ?? "" } set { ham.yaz("id", newValue) } }
    public var ad: String { get { ham.metin("ad") ?? "" } set { ham.yaz("ad", newValue) } }
    public var erkek: Int { get { ham.sayi("erkek") } set { ham.yaz("erkek", newValue) } }
    public var disi: Int { get { ham.sayi("disi") } set { ham.yaz("disi", newValue) } }
    public var toplam: Int { erkek + disi }

    public init(ham: JSONNesne) {
        self.ham = ham
        if (ham.metin("id") ?? "").isEmpty { self.ham.yaz("id", yeniKimlik()) }
    }

    public init(ad: String, erkek: Int = 0, disi: Int = 0, id: String = yeniKimlik()) {
        self.ham = [:]
        self.id = id; self.ad = ad; self.erkek = erkek; self.disi = disi
    }
}

public enum Islem: String, Sendable { case ekle, cikar }

public struct KumesHareketi: Equatable, Sendable {
    public var ham: JSONNesne
    public var islem: Islem { Islem(rawValue: ham.metin("islem") ?? "") ?? .ekle }
    public var erkek: Int { ham.sayi("erkek") }
    public var disi: Int { ham.sayi("disi") }
    public var not: String? { ham.doluMetin("not") }
    public var tarih: String? { ham.doluMetin("tarih") }
    public var irkAd: String? { ham.doluMetin("irkAd") }
    public var dogumTarihi: String? { ham.doluMetin("dogumTarihi") }

    public init(ham: JSONNesne) { self.ham = ham }

    public init(islem: Islem, erkek: Int, disi: Int, not: String, tarih: String, irkAd: String, dogumTarihi: String? = nil) {
        ham = ["islem": .metin(islem.rawValue), "erkek": .s(erkek), "disi": .s(disi),
               "not": .metin(not), "tarih": .metin(tarih), "irkAd": .metin(irkAd),
               "dogumTarihi": .m(dogumTarihi)]
    }
}

public struct Kumes: Identifiable, Equatable, Sendable {
    public var id: String
    public var ad: String
    public var tur: String
    public var irklar: [Irk]
    public var not: String?
    public var hareketler: [KumesHareketi]

    public var turu: HayvanTuru { HayvanTuru.coz(tur) }
    public var erkek: Int { irklar.reduce(0) { $0 + $1.erkek } }
    public var disi: Int { irklar.reduce(0) { $0 + $1.disi } }
    public var toplam: Int { erkek + disi }

    public init(id: String = "", ad: String, tur: String, irklar: [Irk] = [], not: String? = nil, hareketler: [KumesHareketi] = []) {
        self.id = id; self.ad = ad; self.tur = tur; self.irklar = irklar; self.not = not; self.hareketler = hareketler
    }

    public init(satir r: JSONNesne) {
        id = r.metin("id") ?? ""
        ad = r.metin("ad") ?? ""
        tur = r.metin("tur") ?? "diger"
        irklar = (r["irklar"]?.dizi ?? []).compactMap { $0.nesne }.map(Irk.init(ham:))
        not = r.doluMetin("not_")
        hareketler = (r["hareketler"]?.dizi ?? []).compactMap { $0.nesne }.map(KumesHareketi.init(ham:))
    }

    public init(bellek r: JSONNesne) {
        var s = r
        s["not_"] = r["not"]
        self.init(satir: s)
    }

    /// insert/update gövdesi (user_id ve id hariç).
    public var satir: JSONNesne {
        ["ad": .metin(ad), "tur": .metin(tur), "irklar": .dizi(irklar.map { .nesne($0.ham) }),
         "not_": .m(not), "hareketler": .dizi(hareketler.map { .nesne($0.ham) })]
    }

    public var bellek: JSONNesne {
        ["id": .metin(id), "ad": .metin(ad), "tur": .metin(tur), "irklar": .dizi(irklar.map { .nesne($0.ham) }),
         "not": .m(not), "hareketler": .dizi(hareketler.map { .nesne($0.ham) })]
    }

    /// En son eklenen doğum tarihli hareketten yaş (web `yasHesapla`).
    public func sonYas(bugun: Date = Date()) -> String? {
        let son = hareketler.filter { $0.islem == .ekle && $0.dogumTarihi != nil }
            .max { ($0.tarih ?? "") < ($1.tarih ?? "") }
        guard let d = son?.dogumTarihi else { return nil }
        return yasMetni(d, bugun: bugun)
    }
}

// MARK: - Kuluçka

public struct YumurtaKaynagi: Identifiable, Equatable, Sendable {
    public var ham: JSONNesne
    public var id: String { get { ham.metin("id") ?? "" } set { ham.yaz("id", newValue) } }
    public var kumesId: String? { get { ham.doluMetin("kumesId") } set { ham.yaz("kumesId", newValue ?? "") } }
    public var irkId: String? { get { ham.doluMetin("irkId") } set { ham.yaz("irkId", newValue ?? "") } }
    public var adet: Int { get { ham.sayi("adet") } set { ham.yaz("adet", newValue) } }
    public var aciklama: String { get { ham.metin("aciklama") ?? "" } set { ham.yaz("aciklama", newValue) } }

    public init(ham: JSONNesne) {
        self.ham = ham
        if (ham.metin("id") ?? "").isEmpty { self.ham.yaz("id", yeniKimlik()) }
    }

    public init(kumesId: String?, irkId: String? = nil, adet: Int = 0, aciklama: String = "") {
        ham = ["id": .metin(yeniKimlik()), "kumesId": .metin(kumesId ?? ""), "irkId": .metin(irkId ?? ""),
               "adet": .s(adet), "aciklama": .metin(aciklama)]
    }
}

public struct CikimKaynagi: Equatable, Sendable {
    public var kaynakId: String
    public var kumesId: String?
    public var ad: String
    public var yumurta: Int
    public var civciv: Int
    public var olu: Int
    public var bos: Int

    public init(kaynakId: String, kumesId: String?, ad: String, yumurta: Int, civciv: Int = 0, olu: Int = 0, bos: Int = 0) {
        self.kaynakId = kaynakId; self.kumesId = kumesId; self.ad = ad; self.yumurta = yumurta
        self.civciv = civciv; self.olu = olu; self.bos = bos
    }

    public var girilen: Int { civciv + olu + bos }
    public var fark: Int { yumurta - girilen }
}

public struct Cikim: Equatable, Sendable {
    public var ham: JSONNesne
    public var civciv: Int { ham.sayi("civciv") }
    public var olu: Int { ham.sayi("olu") }
    public var bos: Int { ham.sayi("bos") }
    public var tarih: String? { ham.doluMetin("tarih") }
    public var not: String? { ham.doluMetin("not") }
    public var kaynaklar: [JSONNesne] { (ham["kaynaklar"]?.dizi ?? []).compactMap { $0.nesne } }
    public init(ham: JSONNesne) { self.ham = ham }
}

public struct Kulucka: Identifiable, Equatable, Sendable {
    public var id: String
    public var ad: String
    public var baslangic: String
    public var sure: Int
    public var kaynaklar: [YumurtaKaynagi]
    public var toplamYumurta: Int
    public var not: String?
    public var durum: String
    public var cikim: Cikim?

    public var tamamlandi: Bool { durum == "tamamlandi" }
    /// Ana sayfa / widget ile aynı: kaynak adetleri toplamı, yoksa kayıtlı toplam.
    public var yumurta: Int {
        let t = kaynaklar.reduce(0) { $0 + $1.adet }
        return t > 0 ? t : toplamYumurta
    }

    public init(id: String = "", ad: String, baslangic: String, sure: Int, kaynaklar: [YumurtaKaynagi],
                not: String? = nil, durum: String = "devam", cikim: Cikim? = nil) {
        self.id = id; self.ad = ad; self.baslangic = baslangic; self.sure = sure; self.kaynaklar = kaynaklar
        self.toplamYumurta = kaynaklar.reduce(0) { $0 + $1.adet }
        self.not = not; self.durum = durum; self.cikim = cikim
    }

    public init(satir r: JSONNesne) {
        id = r.metin("id") ?? ""
        ad = r.metin("ad") ?? ""
        baslangic = r.metin("baslangic") ?? ""
        sure = r.sayi("sure")
        kaynaklar = (r["kaynaklar"]?.dizi ?? []).compactMap { $0.nesne }.map(YumurtaKaynagi.init(ham:))
        toplamYumurta = r.sayi("toplam_yumurta")
        not = r.doluMetin("not_")
        durum = r.metin("durum") ?? "devam"
        cikim = r["cikim"]?.nesne.map(Cikim.init(ham:))
    }

    public init(bellek r: JSONNesne) {
        var s = r
        s["not_"] = r["not"]
        s["toplam_yumurta"] = r["toplamYumurta"] ?? r["toplam_yumurta"]
        self.init(satir: s)
    }

    public var satir: JSONNesne {
        ["ad": .metin(ad), "baslangic": .metin(baslangic), "sure": .s(sure),
         "kaynaklar": .dizi(kaynaklar.map { .nesne($0.ham) }), "toplam_yumurta": .s(toplamYumurta),
         "not_": .m(not), "durum": .metin(durum), "cikim": cikim.map { .nesne($0.ham) } ?? .null]
    }

    public var bellek: JSONNesne {
        ["id": .metin(id), "ad": .metin(ad), "baslangic": .metin(baslangic), "sure": .s(sure),
         "kaynaklar": .dizi(kaynaklar.map { .nesne($0.ham) }), "toplamYumurta": .s(toplamYumurta),
         "not": .m(not), "durum": .metin(durum), "cikim": cikim.map { .nesne($0.ham) } ?? .null]
    }
}

// MARK: - Civciv ünitesi

public struct UniteHareketi: Equatable, Sendable {
    public var ham: JSONNesne
    public var islem: Islem { Islem(rawValue: ham.metin("islem") ?? "") ?? .ekle }
    public var partiId: String? { ham.doluMetin("partiId") }
    public var adet: Int { get { ham.sayi("adet") } set { ham.yaz("adet", newValue) } }
    public var kalan: Int { get { ham.sayi("kalan") } set { ham.yaz("kalan", newValue) } }
    public var kaynak: String { get { ham.doluMetin("kaynak") ?? "Genel" } set { ham.yaz("kaynak", newValue) } }
    public var not: String? { get { ham.doluMetin("not") } set { ham.yaz("not", newValue ?? "") } }
    public var tarih: String? { get { ham.doluMetin("tarih") } set { ham.yaz("tarih", newValue) } }

    /// Stoğu olan parti mi ("ekle" hareketi = parti).
    public var aktifParti: Bool { islem == .ekle && kalan > 0 }

    public init(ham: JSONNesne) { self.ham = ham }

    public static func parti(adet: Int, kaynak: String, not: String, tarih: String, kaynakKumesId: String? = nil) -> UniteHareketi {
        var h: JSONNesne = ["islem": .metin("ekle"), "partiId": .metin(yeniKimlik()), "adet": .s(adet),
                            "kalan": .s(adet), "kaynak": .metin(kaynak), "not": .metin(not), "tarih": .metin(tarih)]
        if let kaynakKumesId { h["kaynakKumesId"] = .metin(kaynakKumesId) }
        return UniteHareketi(ham: h)
    }

    public static func cikis(adet: Int, partiId: String?, kaynak: String?, not: String, tarih: String) -> UniteHareketi {
        var h: JSONNesne = ["islem": .metin("cikar"), "adet": .s(adet), "not": .metin(not), "tarih": .metin(tarih)]
        if let partiId { h["partiId"] = .metin(partiId) }
        if let kaynak { h["kaynak"] = .metin(kaynak) }
        return UniteHareketi(ham: h)
    }
}

public struct Unite: Identifiable, Equatable, Sendable {
    public var id: String
    public var ad: String
    public var tip: UniteTipi
    public var adet: Int
    public var hareketler: [UniteHareketi]
    /// Yüklerken eski kayıt düzeltildi → DB'ye geri yazılmalı (web dbYukle göçü).
    public var gocGerekli = false

    public init(id: String = "", ad: String, tip: UniteTipi, adet: Int = 0, hareketler: [UniteHareketi] = []) {
        self.id = id; self.ad = ad; self.tip = tip; self.adet = adet; self.hareketler = hareketler
    }

    public static func == (a: Unite, b: Unite) -> Bool {
        a.id == b.id && a.ad == b.ad && a.tip == b.tip && a.adet == b.adet && a.hareketler == b.hareketler
    }

    /// Satırdan okur; web `dbYukle` ile aynı göç: partiId/kalan'sız eski "ekle"ler parti yapılır,
    /// eski "cikar"lar FIFO düşülür, adet parti kalanları toplamına eşitlenir.
    public init(satir r: JSONNesne) {
        id = r.metin("id") ?? ""
        ad = r.metin("ad") ?? ""
        let hr = (r["hareketler"]?.dizi ?? []).compactMap { $0.nesne }
        let meta = hr.first { $0["_meta"]?.bool == true }
        tip = UniteTipi(rawValue: meta?.metin("tip") ?? "civciv") ?? .civciv
        var liste = hr.filter { $0["_meta"]?.bool != true }.map(UniteHareketi.init(ham:))
        var goc = false
        for i in liste.indices where liste[i].islem == .ekle {
            let h = liste[i]
            if h.partiId == nil || h.ham["kalan"] == nil || h.ham["kalan"]?.bosMu == true {
                if h.partiId == nil { liste[i].ham.yaz("partiId", yeniPartiKimligi()) }
                if h.ham["kalan"] == nil || h.ham["kalan"]?.bosMu == true { liste[i].kalan = h.adet }
                if h.ham.doluMetin("kaynak") == nil {
                    var kaynak = "Genel"
                    if let not = h.ham.doluMetin("not"), let r = not.range(of: "—") {
                        let son = not[r.upperBound...].trimmingCharacters(in: .whitespaces)
                        if !son.isEmpty { kaynak = son }
                    }
                    liste[i].kaynak = kaynak
                }
                goc = true
            }
        }
        if goc {
            let sirali = liste.indices.filter { liste[$0].islem == .ekle }
                .sorted { (liste[$0].tarih ?? "") < (liste[$1].tarih ?? "") }
            for c in liste where c.islem == .cikar {
                var kal = c.adet
                for p in sirali where kal > 0 {
                    let dus = min(kal, liste[p].kalan)
                    liste[p].kalan -= dus
                    kal -= dus
                }
            }
        }
        let partiToplam = liste.filter { $0.islem == .ekle }.reduce(0) { $0 + $1.kalan }
        var a = r.sayi("adet")
        if partiToplam != a { a = partiToplam; goc = true }
        adet = a
        hareketler = liste
        gocGerekli = goc
    }

    public init(bellek r: JSONNesne) {
        id = r.metin("id") ?? ""
        ad = r.metin("ad") ?? ""
        tip = UniteTipi(rawValue: r.metin("tip") ?? "civciv") ?? .civciv
        adet = r.sayi("adet")
        hareketler = (r["hareketler"]?.dizi ?? []).compactMap { $0.nesne }
            .filter { $0["_meta"]?.bool != true }.map(UniteHareketi.init(ham:))
    }

    public var satir: JSONNesne {
        ["ad": .metin(ad), "adet": .s(adet),
         "hareketler": .dizi([.nesne(["_meta": .bool(true), "tip": .metin(tip.rawValue)])] + hareketler.map { .nesne($0.ham) })]
    }

    public var bellek: JSONNesne {
        ["id": .metin(id), "ad": .metin(ad), "tip": .metin(tip.rawValue), "adet": .s(adet),
         "hareketler": .dizi(hareketler.map { .nesne($0.ham) })]
    }

    /// Stoğu olan partiler, eskiden yeniye.
    public var aktifPartiler: [UniteHareketi] {
        hareketler.filter(\.aktifParti).sorted { ($0.tarih ?? "") < ($1.tarih ?? "") }
    }

    public func parti(_ partiId: String) -> UniteHareketi? {
        hareketler.first { $0.partiId == partiId && $0.islem == .ekle }
    }

    public var toplamGiren: Int { hareketler.filter { $0.islem == .ekle }.reduce(0) { $0 + $1.adet } }
    public var toplamCikan: Int { hareketler.filter { $0.islem == .cikar }.reduce(0) { $0 + $1.adet } }
}

// MARK: - Satış

public struct SatisUrunu: Identifiable, Equatable, Sendable {
    /// Formda satır kimliği (kaydedilmez).
    public let id = UUID()
    public var ham: JSONNesne
    public var tip: UrunTipi { get { UrunTipi(rawValue: ham.metin("tip") ?? "") ?? .diger } set { ham.yaz("tip", newValue.rawValue) } }
    public var kumesId: String? { get { ham.doluMetin("kumesId") } set { ham.yaz("kumesId", newValue ?? "") } }
    public var irkId: String? { get { ham.doluMetin("irkId") } set { ham.yaz("irkId", newValue ?? "") } }
    public var irkAd: String? { get { ham.doluMetin("irkAd") } set { ham["irkAd"] = .m(newValue) } }
    public var uniteId: String? { get { ham.doluMetin("uniteId") } set { ham.yaz("uniteId", newValue ?? "") } }
    public var partiId: String? { get { ham.doluMetin("partiId") } set { ham.yaz("partiId", newValue ?? "") } }
    public var adet: Int { get { ham.sayi("adet") } set { ham.yaz("adet", newValue) } }
    public var erkekAdet: Int { get { ham.sayi("erkekAdet") } set { ham.yaz("erkekAdet", newValue) } }
    public var disiAdet: Int { get { ham.sayi("disiAdet") } set { ham.yaz("disiAdet", newValue) } }
    public var fiyat: Double { get { ham.ondalik("fiyat") } set { ham.yaz("fiyat", newValue) } }
    public var ad: String { get { ham.metin("ad") ?? "" } set { ham.yaz("ad", newValue) } }

    public var tutar: Double { Double(adet) * fiyat }
    /// Listede görünen ad (web `u.ad || u.irkAd || u.tip`).
    public var gorunenAd: String {
        if !ad.isEmpty { return ad }
        if let irkAd { return irkAd }
        return ham.metin("tip") ?? "ürün"
    }

    public init(ham: JSONNesne) {
        self.ham = ham
        // Eski hayvan kayıtları: erkek/dişi yoksa adet yarı yarıya (web editSat)
        if tip == .hayvan, ham["erkekAdet"] == nil || ham["disiAdet"] == nil {
            let e = adet / 2
            erkekAdet = e
            disiAdet = adet - e
        }
    }

    public static func == (a: SatisUrunu, b: SatisUrunu) -> Bool { a.ham == b.ham }

    public static func yeni(tip: UrunTipi = .hayvan, kumesId: String?, irkId: String?, uniteId: String?) -> SatisUrunu {
        SatisUrunu(ham: ["tip": .metin(tip.rawValue), "kumesId": .metin(kumesId ?? ""), "irkId": .metin(irkId ?? ""),
                         "uniteId": .metin(uniteId ?? ""), "partiId": .metin(""), "adet": .s(0),
                         "erkekAdet": .s(0), "disiAdet": .s(0), "fiyat": .s(0), "ad": .metin("")])
    }
}

public struct Satis: Identifiable, Equatable, Sendable {
    public var id: String
    public var musteri: String?
    public var tarih: String
    public var urunler: [SatisUrunu]
    public var toplam: Double
    public var odenen: Double
    public var not: String?

    public var kalan: Double { max(0, toplam - odenen) }
    public var musteriAdi: String { (musteri ?? "").trimmingCharacters(in: .whitespaces).isEmpty ? "Anonim" : musteri!.trimmingCharacters(in: .whitespaces) }

    public init(id: String = "", musteri: String?, tarih: String, urunler: [SatisUrunu], toplam: Double, odenen: Double, not: String?) {
        self.id = id; self.musteri = musteri; self.tarih = tarih; self.urunler = urunler
        self.toplam = toplam; self.odenen = odenen; self.not = not
    }

    public init(satir r: JSONNesne) {
        id = r.metin("id") ?? ""
        musteri = r.doluMetin("musteri")
        tarih = r.metin("tarih") ?? ""
        urunler = (r["urunler"]?.dizi ?? []).compactMap { $0.nesne }.map(SatisUrunu.init(ham:))
        toplam = r.ondalik("toplam")
        // odenen yoksa (eski kayıt) tamamı ödenmiş sayılır
        if let o = r["odenen"], !o.bosMu { odenen = o.double ?? 0 } else { odenen = toplam }
        not = r.doluMetin("not_")
    }

    public init(bellek r: JSONNesne) {
        var s = r
        s["not_"] = r["not"]
        self.init(satir: s)
    }

    public var satir: JSONNesne {
        ["musteri": .m(musteri), "tarih": .metin(tarih), "urunler": .dizi(urunler.map { .nesne($0.ham) }),
         "toplam": .s(toplam), "odenen": .s(odenen), "not_": .m(not)]
    }

    public var bellek: JSONNesne {
        ["id": .metin(id), "musteri": .m(musteri), "tarih": .metin(tarih), "urunler": .dizi(urunler.map { .nesne($0.ham) }),
         "toplam": .s(toplam), "odenen": .s(odenen), "kalan": .s(kalan), "not": .m(not)]
    }

    public var urunOzeti: String { urunler.map { "\($0.adet) \($0.gorunenAd)" }.joined(separator: " + ") }
}

// MARK: - Gider

public struct Gider: Identifiable, Equatable, Sendable {
    public var id: String
    public var tur: String
    public var aciklama: String?
    public var tutar: Double
    public var tarih: String
    public var kumesId: String?
    public var odenen: Double

    public var kalan: Double { max(0, tutar - odenen) }
    public var turu: GiderTuru { GiderTuru.coz(tur) }
    public var baslik: String { aciklama ?? turu.ad }

    public init(id: String = "", tur: String, aciklama: String?, tutar: Double, tarih: String, kumesId: String?, odenen: Double) {
        self.id = id; self.tur = tur; self.aciklama = aciklama; self.tutar = tutar; self.tarih = tarih
        self.kumesId = kumesId; self.odenen = odenen
    }

    public init(satir r: JSONNesne) {
        id = r.metin("id") ?? ""
        tur = r.metin("tur") ?? "diger"
        aciklama = r.doluMetin("aciklama")
        tutar = r.ondalik("tutar")
        tarih = r.metin("tarih") ?? ""
        kumesId = r.doluMetin("kumes_id")
        if let o = r["odenen"], !o.bosMu { odenen = o.double ?? 0 } else { odenen = tutar }
    }

    public init(bellek r: JSONNesne) {
        var s = r
        s["kumes_id"] = r["kumesId"]
        self.init(satir: s)
    }

    public var satir: JSONNesne {
        ["tur": .metin(tur), "aciklama": .m(aciklama), "tutar": .s(tutar), "tarih": .metin(tarih),
         "kumes_id": .m(kumesId), "odenen": .s(odenen)]
    }

    public var bellek: JSONNesne {
        ["id": .metin(id), "tur": .metin(tur), "aciklama": .m(aciklama), "tutar": .s(tutar), "tarih": .metin(tarih),
         "kumesId": .m(kumesId), "odenen": .s(odenen), "kalan": .s(kalan)]
    }
}

// MARK: - Sezon arşivi

public struct Sezon: Identifiable, Equatable, Sendable {
    public var id: String
    public var ad: String
    public var tarih: String
    public var veri: JSONNesne

    public init(satir r: JSONNesne) {
        id = r.metin("id") ?? ""
        ad = r.metin("ad") ?? ""
        tarih = r.metin("tarih") ?? ""
        veri = r["veri"]?.nesne ?? [:]
    }

    public var satisSayisi: Int { veri["satislar"]?.dizi?.count ?? 0 }
    public var kumesSayisi: Int { veri["kumesler"]?.dizi?.count ?? 0 }
    public var ham: JSONNesne { ["id": .metin(id), "ad": .metin(ad), "tarih": .metin(tarih), "veri": .nesne(veri)] }

    /// Arşivdeki anlık görüntü (web bellek biçimi).
    public var anlikVeri: Veri { Veri(bellek: veri) }
}
