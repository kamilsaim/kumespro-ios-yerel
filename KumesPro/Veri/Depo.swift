import Foundation
import Observation
import Supabase
import KumesCekirdek

/// Uygulama verisi + Supabase'e yazma (web `D` + `db*` fonksiyonları).
/// Her işlem `Veri`'nin kopyası üzerinde çekirdek kuralıyla yapılır; yalnız değişen satırlar kaydedilir,
/// kayıt başarılıysa ekrandaki veri güncellenir. Arşiv (sezon) görüntülenirken yazma kapalıdır.
@Observable @MainActor
final class Depo {
    private(set) var veri = Veri()
    private(set) var yuklendi = false
    private(set) var yukleniyor = false
    var hata: String?
    /// Görüntülenen sezon arşivi; nil = canlı veri.
    private(set) var arsiv: Sezon?
    private(set) var sezonlar: [Sezon] = []

    @ObservationIgnored private var kullanici: String?
    @ObservationIgnored private var yaziliyor = false
    @ObservationIgnored private var sunucuSatirlari: [String: [String: JSONNesne]] = [:]

    private func kaliciKimlik() -> String { UUID().uuidString.lowercased() }

    private func satirlar(_ v: Veri) -> [(String, [(String, JSONNesne)])] {
        [
            ("kumesler", v.kumesler.map { ($0.id, $0.satir) }),
            ("civciv_uniteleri", v.uniteler.map { ($0.id, $0.satir) }),
            ("kuluckalar", v.kuluckalar.map { ($0.id, $0.satir) }),
            ("satislar", v.satislar.map { ($0.id, $0.satir) }),
            ("giderler", v.giderler.map { ($0.id, $0.satir) })
        ]
    }

    private func bekleyenDosya(_ uid: String) throws -> URL {
        let klasor = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true)
        return klasor.appendingPathComponent("kp-islem-" + uid + ".json")
    }

    /// Aynı istek kimliği tekrar gönderilir. Sunucu daha önce tamamladıysa ikinci kez uygulamaz.
    private func bekleyeniTamamla(_ uid: String) async throws {
        let dosya = try bekleyenDosya(uid)
        guard FileManager.default.fileExists(atPath: dosya.path) else { return }
        let istek = try JSONDecoder().decode(JSONNesne.self, from: Data(contentsOf: dosya))
        do {
            try await supabase.rpc("kp_atomik_islem", params: istek).execute()
            try FileManager.default.removeItem(at: dosya)
        } catch let e as PostgrestError {
            // PostgreSQL bu hatalarda transaction'ı geri almıştır.
            if ["40001", "PGRST202", "42501", "23503", "23514", "P0001", "22023"].contains(e.code ?? "") {
                try FileManager.default.removeItem(at: dosya)
            }
            throw e
        }
    }

    /// İlgili tüm satırlar tek transaction'da kaydedilir. Çakışmada bütün işlem geri alınır.
    private func atomikKaydet(_ yeni: Veri, ek: [JSONNesne] = []) async throws {
        try yazilabilir()
        guard let uid = kullanici else { throw KuralHatasi("Oturum bulunamadı.") }
        guard !yaziliyor else { throw KuralHatasi("Önceki işlemin bitmesini bekleyin.") }
        let dosya = try bekleyenDosya(uid)
        guard !FileManager.default.fileExists(atPath: dosya.path) else {
            throw KuralHatasi("Önceki işlemin sonucu doğrulanmalı. Verileri yenileyip tekrar deneyin.")
        }
        let onceki = Dictionary(uniqueKeysWithValues: satirlar(veri))
        let sonraki = satirlar(yeni)
        var islemler = ek
        for (tablo, kayitlar) in sonraki {
            let eski = Dictionary(uniqueKeysWithValues: onceki[tablo] ?? [])
            for (id, satir) in kayitlar {
                if let eskiSatir = eski[id] {
                    if eskiSatir != satir {
                        let ham = sunucuSatirlari[tablo]?[id] ?? eskiSatir
                        let beklenen = ham.filter { eskiSatir.keys.contains($0.key) }
                        islemler.append(["tablo": .metin(tablo), "tur": .metin("guncelle"), "id": .metin(id),
                                         "veri": .nesne(satir), "beklenen": .nesne(beklenen)])
                    }
                } else {
                    islemler.append(["tablo": .metin(tablo), "tur": .metin("ekle"), "id": .metin(id), "veri": .nesne(satir)])
                }
            }
        }
        for (tablo, kayitlar) in sonraki.reversed() {
            let kalan = Set(kayitlar.map { $0.0 })
            for (id, satir) in onceki[tablo] ?? [] where !kalan.contains(id) {
                let ham = sunucuSatirlari[tablo]?[id] ?? satir
                let beklenen = ham.filter { satir.keys.contains($0.key) }
                islemler.append(["tablo": .metin(tablo), "tur": .metin("sil"), "id": .metin(id), "beklenen": .nesne(beklenen)])
            }
        }
        guard !islemler.isEmpty else { return }
        yaziliyor = true
        defer { yaziliyor = false }
        let istek: JSONNesne = ["istek_id": .metin(kaliciKimlik()), "islemler": .dizi(islemler.map { .nesne($0) }),
                                "kullanici_id": .metin(uid)]
        let data = try JSONEncoder().encode(istek)
        try data.write(to: dosya, options: [.atomic, .completeFileProtection])
        var ayarlar = URLResourceValues()
        ayarlar.isExcludedFromBackup = true
        var dosyaURL = dosya
        try dosyaURL.setResourceValues(ayarlar)
        try await bekleyeniTamamla(uid)
        guard uid == kullanici else { return }
        veri = yeni
        for (tablo, kayitlar) in satirlar(yeni) {
            sunucuSatirlari[tablo] = Dictionary(uniqueKeysWithValues: kayitlar)
        }
        yerelleriTazele()
    }

    private func arsivIslemi(ad: String) -> JSONNesne {
        ["tablo": .metin("sezonlar"), "tur": .metin("ekle"), "id": .metin(kaliciKimlik()),
         "veri": .nesne(["ad": .metin(ad), "tarih": .metin(Gun.bugun), "veri": .nesne(veri.bellek)])]
    }

    var saltOkunur: Bool { arsiv != nil }

    // MARK: Yükleme

    func baslat(kullanici: String?) async {
        guard kullanici != self.kullanici else { return }
        self.kullanici = kullanici
        veri = Veri(); arsiv = nil; sezonlar = []; sunucuSatirlari = [:]; hata = nil; yuklendi = false
        guard kullanici != nil else { return }
        await yukle()
    }

    private func liste(_ tablo: String, uid: String) async throws -> [JSONNesne] {
        var tum: [JSONNesne] = []
        var baslangic = 0
        while true {
            let sayfa: [JSONNesne] = try await supabase.from(tablo).select().eq("user_id", value: uid)
                .order("id").range(from: baslangic, to: baslangic + 499).execute().value
            tum += sayfa
            if sayfa.count < 500 { break }
            baslangic += 500
        }
        if tablo == "satislar" || tablo == "giderler" {
            tum.sort { ($0.metin("tarih") ?? "") > ($1.metin("tarih") ?? "") }
        }
        return tum
    }

    func yukle() async {
        guard let uid = kullanici, !yaziliyor, !yukleniyor else { return }
        yukleniyor = true
        defer { yukleniyor = false }
        do {
            try await bekleyeniTamamla(uid)
            async let k = liste("kumesler", uid: uid)
            async let ku = liste("kuluckalar", uid: uid)
            async let u = liste("civciv_uniteleri", uid: uid)
            async let s = liste("satislar", uid: uid)
            async let g = liste("giderler", uid: uid)
            let (kr, kur, ur, sr, gr) = try await (k, ku, u, s, g)
            guard uid == kullanici else { return }
            for (tablo, kayitlar) in [("kumesler", kr), ("kuluckalar", kur), ("civciv_uniteleri", ur),
                                     ("satislar", sr), ("giderler", gr)] {
                sunucuSatirlari[tablo] = Dictionary(uniqueKeysWithValues: kayitlar.compactMap { r in
                    r.metin("id").map { ($0, r) }
                })
            }
            let v = Veri(kumesler: kr.map(Kumes.init(satir:)), kuluckalar: kur.map(Kulucka.init(satir:)),
                         uniteler: ur.map(Unite.init(satir:)), satislar: sr.map(Satis.init(satir:)),
                         giderler: gr.map(Gider.init(satir:)))
            veri = v
            arsiv = nil
            yuklendi = true
            hata = nil
            yerelleriTazele()
        } catch {
            if uid == kullanici { hata = "Veriler yüklenemedi. İnternet bağlantını kontrol edip tekrar dene." }
        }
    }

    /// Widget + yerel bildirimler (yalnız canlı veride).
    func yerelleriTazele() {
        guard arsiv == nil, yuklendi else { return }
        WidgetKoprusu.yaz(veri.widgetJSON)
        Task { await YerelBildirim.kur(veri.bildirimPlani()) }
    }

    // MARK: Genel değiştirme kalıbı

    private func yazilabilir() throws {
        if !yuklendi || yukleniyor || yaziliyor { throw KuralHatasi("Veri işleminin bitmesini bekleyin.") }
        if arsiv != nil { throw KuralHatasi("Arşiv görüntüleme modundasınız. Önce canlı veriye dönün.") }
        if kullanici == nil { throw KuralHatasi("Oturum bulunamadı.") }
    }

    /// Çekirdek kuralını kopya üzerinde çalıştırır, değişen kümes/üniteleri kaydeder, sonra ekrana yansıtır.
    private func degistir(_ islem: (inout Veri) throws -> Degisenler) async throws {
        try yazilabilir()
        var v = veri
        _ = try islem(&v)
        try await atomikKaydet(v)
    }

    // MARK: Kümes

    func kumesKaydet(_ k: Kumes) async throws {
        try yazilabilir()
        var v = veri
        var k = k
        if k.id.isEmpty { k.id = kaliciKimlik(); v.kumesler.append(k) }
        else if let i = v.kumesler.firstIndex(where: { $0.id == k.id }) {
            k.hareketler = v.kumesler[i].hareketler
            v.kumesler[i] = k
        } else { throw KuralHatasi("Kümes bulunamadı.") }
        try await atomikKaydet(v)
    }

    func kumesSil(_ id: String) async throws {
        var v = veri
        v.kumesler.removeAll { $0.id == id }
        try await atomikKaydet(v)
    }

    func hayvanIslemi(kumesId: String, islem: Islem, irkId: String?, erkek: Int, disi: Int, not: String, dogum: String?) async throws {
        try await degistir { v in
            try v.hayvanIslemi(kumesId: kumesId, islem: islem, irkId: irkId, erkek: erkek, disi: disi,
                               not: not, dogumTarihi: dogum)
            var d = Degisenler(); d.kumesler = [kumesId]; return d
        }
    }

    func kumesHareketiSil(kumesId: String, indeks: Int) async throws {
        try await degistir { v in
            v.kumesHareketiSil(kumesId: kumesId, indeks: indeks)
            var d = Degisenler(); d.kumesler = [kumesId]; return d
        }
    }

    // MARK: Ünite

    @discardableResult
    func uniteEkle(ad: String, tip: UniteTipi, adet: Int, tarih: String) async throws -> String {
        var v = veri
        let id = kaliciKimlik()
        var u = Unite(id: id, ad: ad, tip: tip, adet: max(0, adet))
        if adet > 0 { u.hareketler = [.parti(adet: adet, kaynak: "Başlangıç", not: "Başlangıç", tarih: tarih)] }
        v.uniteler.append(u)
        try await atomikKaydet(v)
        return id
    }

    func uniteAdiDegistir(_ id: String, ad: String, tip: UniteTipi) async throws {
        try await degistir { v in
            guard let i = v.uniteler.firstIndex(where: { $0.id == id }) else { throw KuralHatasi("Ünite bulunamadı!") }
            v.uniteler[i].ad = ad; v.uniteler[i].tip = tip
            var d = Degisenler(); d.uniteler = [id]; return d
        }
    }

    func uniteSil(_ id: String) async throws {
        var v = veri
        v.uniteler.removeAll { $0.id == id }
        try await atomikKaydet(v)
    }

    private func uniteDegistir(_ uniteId: String, _ islem: @escaping (inout Veri) throws -> Void) async throws {
        try await degistir { v in
            try islem(&v)
            var d = Degisenler(); d.uniteler = [uniteId]; return d
        }
    }

    func partiEkle(uniteId: String, adet: Int, kaynak: String, not: String, tarih: String) async throws {
        try await uniteDegistir(uniteId) { try $0.partiEkle(uniteId: uniteId, adet: adet, kaynak: kaynak, not: not, tarih: tarih) }
    }

    func partidenCikar(uniteId: String, partiId: String, adet: Int, not: String, tarih: String) async throws {
        try await uniteDegistir(uniteId) { try $0.partidenCikar(uniteId: uniteId, partiId: partiId, adet: adet, not: not, tarih: tarih) }
    }

    func partiDuzenle(uniteId: String, partiId: String, kaynak: String, adet: Int, kalan: Int, tarih: String, not: String) async throws {
        try await uniteDegistir(uniteId) {
            try $0.partiDuzenle(uniteId: uniteId, partiId: partiId, kaynak: kaynak, adet: adet, kalan: kalan, tarih: tarih, not: not)
        }
    }

    func partiSil(uniteId: String, partiId: String) async throws {
        try await uniteDegistir(uniteId) { $0.partiSil(uniteId: uniteId, partiId: partiId) }
    }

    func kumeseAktar(uniteId: String, partiId: String, kumesId: String, irkId: String?, yeniIrk: String,
                     erkek: Int, disi: Int, not: String, tarih: String) async throws {
        try await degistir { v in
            try v.kumeseAktar(uniteId: uniteId, partiId: partiId, kumesId: kumesId, irkId: irkId, yeniIrkAdi: yeniIrk,
                              erkek: erkek, disi: disi, not: not, tarih: tarih)
        }
    }

    // MARK: Kuluçka

    func kuluckaKaydet(_ k: Kulucka) async throws {
        var v = veri
        var k = k
        k.toplamYumurta = k.kaynaklar.reduce(0) { $0 + $1.adet }
        if k.id.isEmpty { k.id = kaliciKimlik(); v.kuluckalar.append(k) }
        else if let i = v.kuluckalar.firstIndex(where: { $0.id == k.id }) {
            k.durum = v.kuluckalar[i].durum
            k.cikim = v.kuluckalar[i].cikim
            v.kuluckalar[i] = k
        } else { throw KuralHatasi("Kuluçka bulunamadı.") }
        try await atomikKaydet(v)
    }

    func kuluckaSil(_ id: String) async throws {
        var v = veri
        v.kuluckalar.removeAll { $0.id == id }
        try await atomikKaydet(v)
    }

    /// Çıkımı kaydeder; `yeniUniteAdi` doluysa önce ünite oluşturulur. Toplam civcivi döner.
    @discardableResult
    func cikimKaydet(kuluckaId: String, satirlar: [CikimKaynagi], tarih: String, not: String,
                     uniteId: String?, yeniUniteAdi: String?, yeniUniteTipi: UniteTipi) async throws -> (Int, String?) {
        try yazilabilir()
        var hedef = uniteId
        var v = veri
        let toplam = satirlar.reduce(0) { $0 + $1.civciv }
        if let ad = yeniUniteAdi?.trimmingCharacters(in: .whitespaces), !ad.isEmpty, toplam > 0 {
            let id = kaliciKimlik()
            v.uniteler.append(Unite(id: id, ad: ad, tip: yeniUniteTipi))
            hedef = id
        }
        let degisen = try v.cikimKaydet(kuluckaId: kuluckaId, satirlar: satirlar, tarih: tarih, not: not, uniteId: hedef)
        try await atomikKaydet(v)
        yerelleriTazele()
        return (toplam, degisen.flatMap { v.unite($0)?.ad })
    }

    // MARK: Satış

    func satisKaydet(eskiId: String?, musteri: String, tarih: String, urunler: [SatisUrunu], odenen: Double?, not: String) async throws {
        try yazilabilir()
        let eski = eskiId.flatMap { id in veri.satislar.first { $0.id == id } }
        if eskiId != nil, eski == nil { throw KuralHatasi("Satış bulunamadı. Verileri yenileyin.") }
        try veri.satisDogrula(urunler, eski: eski)
        var u = urunler
        let toplam = u.reduce(0.0) { r, x in
            let adet = x.tip == .hayvan ? x.erkekAdet + x.disiAdet : x.adet
            return r + Double(adet) * x.fiyat
        }
        let ode = odenen ?? toplam
        guard toplam.isFinite, ode.isFinite, ode >= 0 else { throw KuralHatasi("Ödenen tutar geçersiz!") }
        guard ode <= toplam + 0.001 else {
            throw KuralHatasi("Ödenen tutar (\(para(ode))) satış toplamını (\(para(toplam))) geçemez!")
        }
        let mus = musteri.trimmingCharacters(in: .whitespaces)
        var v = veri
        _ = v.satisUygula(&u, eski: eski, musteri: mus, tarih: tarih)
        let n = not.trimmingCharacters(in: .whitespaces)
        let s = Satis(id: eski?.id ?? kaliciKimlik(), musteri: mus.isEmpty ? nil : mus, tarih: tarih, urunler: u,
                      toplam: toplam, odenen: min(ode, toplam), not: n.isEmpty ? nil : n)
        if let eski {
            if let i = v.satislar.firstIndex(where: { $0.id == eski.id }) { v.satislar[i] = s }
        } else {
            v.satislar.insert(s, at: 0)
        }
        try await atomikKaydet(v)
    }

    func satisSil(_ id: String) async throws {
        try yazilabilir()
        guard let s = veri.satislar.first(where: { $0.id == id }) else { return }
        var v = veri
        _ = v.satisStokIade(s, notOnEk: "Satış iptali")
        v.satislar.removeAll { $0.id == id }
        try await atomikKaydet(v)
    }

    /// Kalan alacağı tahsil edildi say (web `satisBorcAl`).
    func tahsilEt(_ id: String) async throws {
        var v = veri
        guard let i = v.satislar.firstIndex(where: { $0.id == id }) else { return }
        v.satislar[i].odenen = v.satislar[i].toplam
        try await atomikKaydet(v)
    }

    // MARK: Gider

    func giderKaydet(_ g: Gider) async throws {
        guard g.tutar.isFinite, g.tutar > 0, g.odenen.isFinite, g.odenen >= 0, g.odenen <= g.tutar + 0.001 else {
            throw KuralHatasi("Gider ve ödenen tutarı kontrol edin.")
        }
        var v = veri
        var g = g
        g.odenen = min(g.odenen, g.tutar)
        if g.id.isEmpty { g.id = kaliciKimlik(); v.giderler.insert(g, at: 0) }
        else if let i = v.giderler.firstIndex(where: { $0.id == g.id }) { v.giderler[i] = g }
        else { throw KuralHatasi("Gider bulunamadı.") }
        try await atomikKaydet(v)
    }

    func giderSil(_ id: String) async throws {
        var v = veri
        v.giderler.removeAll { $0.id == id }
        try await atomikKaydet(v)
    }

    func borcOde(_ id: String) async throws {
        var v = veri
        guard let i = v.giderler.firstIndex(where: { $0.id == id }) else { return }
        v.giderler[i].odenen = v.giderler[i].tutar
        try await atomikKaydet(v)
    }

    // MARK: Sezon arşivi

    func sezonlariYukle() async {
        guard let uid = kullanici else { return }
        do {
            let r = try await liste("sezonlar", uid: uid)
            guard uid == kullanici else { return }
            sezonlar = r.map(Sezon.init(satir:))
        } catch {
            hata = "Sezon arşivleri yüklenemedi. Lütfen tekrar deneyin."
        }
    }

    func sezonGor(_ s: Sezon) {
        arsiv = s
        veri = s.anlikVeri
    }

    func canliyaDon() async {
        await yukle()
    }

    func sezonSil(_ id: String) async throws {
        guard let uid = kullanici else { return }
        try await supabase.from("sezonlar").delete(returning: .minimal).eq("id", value: id).eq("user_id", value: uid).execute()
        sezonlar.removeAll { $0.id == id }
    }

    // MARK: Yedekten geri yükleme

    func yedekYukle(_ y: Yedek) async throws -> Int {
        try yazilabilir()
        var v = y.veri
        var km: [String: String] = [:]
        for i in v.kumesler.indices {
            let eski = v.kumesler[i].id
            let yeni = kaliciKimlik()
            km[eski] = yeni
            v.kumesler[i].id = yeni
        }
        v.kumesKimlikleriniEsle(km)
        if v.uniteler.isEmpty { v.uniteler = [Unite(ad: "Genel Civciv Ünitesi", tip: .civciv)] }
        var um: [String: String] = [:]
        for i in v.uniteler.indices {
            let eski = v.uniteler[i].id
            let yeni = kaliciKimlik()
            um[eski] = yeni
            v.uniteler[i].id = yeni
        }
        v.uniteKimlikleriniEsle(um)
        for i in v.kuluckalar.indices { v.kuluckalar[i].id = kaliciKimlik() }
        for i in v.satislar.indices { v.satislar[i].id = kaliciKimlik() }
        for i in v.giderler.indices { v.giderler[i].id = kaliciKimlik() }
        await sezonlariYukle()
        let mevcut = Set(sezonlar.map(\.id))
        var ek = [arsivIslemi(ad: "Yedek öncesi " + Gun.goster(Date()))]
        for s in y.sezonlar where !mevcut.contains(s.metin("id") ?? "") {
            let id = s.doluMetin("id") ?? kaliciKimlik()
            ek.append(["tablo": .metin("sezonlar"), "tur": .metin("ekle"), "id": .metin(id),
                       "veri": .nesne(["ad": s["ad"] ?? .metin("Sezon"), "tarih": s["tarih"] ?? .metin(Gun.bugun),
                                       "veri": s["veri"] ?? .nesne([:])])])
        }
        try await atomikKaydet(v, ek: ek)
        await sezonlariYukle()
        return y.kayitSayisi
    }

    /// Yeni sezon (web `yeniSezonOlustur`): arşivle, satış/gider ve tamamlanmış kuluçkaları sil.
    func yeniSezon(ad: String) async throws {
        try yazilabilir()
        var v = veri
        v.satislar = []
        v.giderler = []
        v.kuluckalar.removeAll { $0.tamamlandi }
        try await atomikKaydet(v, ek: [arsivIslemi(ad: ad)])
    }

    func yilSonu(alacakDevret: Bool, borcDevret: Bool, bitenKuluckalariSil: Bool) async throws -> String {
        try yazilabilir()
        var v = veri
        let dev = veri.devredenler(alacak: alacakDevret, borc: borcDevret)
        v.satislar = dev.satislar
        v.giderler = dev.giderler
        for i in v.satislar.indices { v.satislar[i].id = kaliciKimlik() }
        for i in v.giderler.indices { v.giderler[i].id = kaliciKimlik() }
        if bitenKuluckalariSil { v.kuluckalar.removeAll { $0.tamamlandi } }
        try await atomikKaydet(v, ek: [arsivIslemi(ad: "Yıl Sonu " + Gun.goster(Date()))])
        return "Yeni döneme geçildi. Önceki veriler sezon arşivine kaydedildi."
    }
}
