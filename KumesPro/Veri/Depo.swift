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

    var saltOkunur: Bool { arsiv != nil }

    // MARK: Yükleme

    func baslat(kullanici: String?) async {
        guard kullanici != self.kullanici else { return }
        self.kullanici = kullanici
        veri = Veri(); arsiv = nil; sezonlar = []; yuklendi = false
        guard kullanici != nil else { return }
        await yukle()
    }

    func yukle() async {
        guard let uid = kullanici else { return }
        yukleniyor = true
        defer { yukleniyor = false }
        do {
            async let k: [JSONNesne] = supabase.from("kumesler").select().eq("user_id", value: uid)
                .order("created_at").execute().value
            async let ku: [JSONNesne] = supabase.from("kuluckalar").select().eq("user_id", value: uid)
                .order("created_at").execute().value
            async let u: [JSONNesne] = supabase.from("civciv_uniteleri").select().eq("user_id", value: uid)
                .order("created_at").execute().value
            async let s: [JSONNesne] = supabase.from("satislar").select().eq("user_id", value: uid)
                .order("tarih", ascending: false).execute().value
            async let g: [JSONNesne] = supabase.from("giderler").select().eq("user_id", value: uid)
                .order("tarih", ascending: false).execute().value
            let (kr, kur, ur, sr, gr) = try await (k, ku, u, s, g)
            guard uid == kullanici else { return }
            var v = Veri(kumesler: kr.map(Kumes.init(satir:)), kuluckalar: kur.map(Kulucka.init(satir:)),
                         uniteler: ur.map(Unite.init(satir:)), satislar: sr.map(Satis.init(satir:)),
                         giderler: gr.map(Gider.init(satir:)))
            // Eski ünite kayıtları düzeltildiyse geri yaz (web dbYukle göçü)
            for i in v.uniteler.indices where v.uniteler[i].gocGerekli {
                v.uniteler[i].gocGerekli = false
                try? await uniteYaz(v.uniteler[i])
            }
            veri = v
            arsiv = nil
            yuklendi = true
            hata = nil
            yerelleriTazele()
        } catch {
            if !yuklendi { hata = "Veriler yüklenemedi. İnternet bağlantını kontrol edip tekrar dene." }
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
        if arsiv != nil { throw KuralHatasi("Arşiv görüntüleme modundasınız. Önce canlı veriye dönün.") }
        if kullanici == nil { throw KuralHatasi("Oturum bulunamadı.") }
    }

    /// Çekirdek kuralını kopya üzerinde çalıştırır, değişen kümes/üniteleri kaydeder, sonra ekrana yansıtır.
    private func degistir(_ islem: (inout Veri) throws -> Degisenler) async throws {
        try yazilabilir()
        var v = veri
        let d = try islem(&v)
        for id in d.kumesler { if let k = v.kumes(id) { try await kumesYaz(k) } }
        for id in d.uniteler { if let u = v.unite(id) { try await uniteYaz(u) } }
        veri = v
    }

    private func kumesYaz(_ k: Kumes) async throws {
        try await supabase.from("kumesler").update(k.satir, returning: .minimal).eq("id", value: k.id).execute()
    }

    private func uniteYaz(_ u: Unite) async throws {
        try await supabase.from("civciv_uniteleri").update(u.satir, returning: .minimal).eq("id", value: u.id).execute()
    }

    private func ekle(_ tablo: String, _ satir: JSONNesne) async throws -> String {
        var s = satir
        s["user_id"] = .metin(kullanici ?? "")
        let r: JSONNesne = try await supabase.from(tablo).insert(s, returning: .representation)
            .select().single().execute().value
        guard let id = r.metin("id") else { throw KuralHatasi("Kayıt oluşturulamadı.") }
        return id
    }

    private func guncelle(_ tablo: String, _ id: String, _ satir: JSONNesne) async throws {
        try await supabase.from(tablo).update(satir, returning: .minimal).eq("id", value: id).execute()
    }

    private func sil(_ tablo: String, _ id: String) async throws {
        try await supabase.from(tablo).delete(returning: .minimal).eq("id", value: id).execute()
    }

    // MARK: Kümes

    func kumesKaydet(_ k: Kumes) async throws {
        try yazilabilir()
        var k = k
        if k.id.isEmpty {
            k.id = try await ekle("kumesler", k.satir)
            veri.kumesler.append(k)
        } else {
            // hareketler kayıtlı halinden korunur (form yalnız ad/tür/ırk/not düzenler)
            if let eski = veri.kumes(k.id) { k.hareketler = eski.hareketler }
            try await kumesYaz(k)
            if let i = veri.kumesler.firstIndex(where: { $0.id == k.id }) { veri.kumesler[i] = k }
        }
    }

    func kumesSil(_ id: String) async throws {
        try yazilabilir()
        try await sil("kumesler", id)
        veri.kumesler.removeAll { $0.id == id }
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
        try yazilabilir()
        var u = Unite(ad: ad, tip: tip, adet: max(0, adet))
        if adet > 0 { u.hareketler = [.parti(adet: adet, kaynak: "Başlangıç", not: "Başlangıç", tarih: tarih)] }
        u.id = try await ekle("civciv_uniteleri", u.satir)
        veri.uniteler.append(u)
        return u.id
    }

    func uniteAdiDegistir(_ id: String, ad: String, tip: UniteTipi) async throws {
        try await degistir { v in
            guard let i = v.uniteler.firstIndex(where: { $0.id == id }) else { throw KuralHatasi("Ünite bulunamadı!") }
            v.uniteler[i].ad = ad; v.uniteler[i].tip = tip
            var d = Degisenler(); d.uniteler = [id]; return d
        }
    }

    func uniteSil(_ id: String) async throws {
        try yazilabilir()
        try await sil("civciv_uniteleri", id)
        veri.uniteler.removeAll { $0.id == id }
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
        try yazilabilir()
        var k = k
        k.toplamYumurta = k.kaynaklar.reduce(0) { $0 + $1.adet }
        if k.id.isEmpty {
            k.id = try await ekle("kuluckalar", k.satir)
            veri.kuluckalar.append(k)
        } else {
            if let eski = veri.kuluckalar.first(where: { $0.id == k.id }) { k.durum = eski.durum; k.cikim = eski.cikim }
            try await guncelle("kuluckalar", k.id, k.satir)
            if let i = veri.kuluckalar.firstIndex(where: { $0.id == k.id }) { veri.kuluckalar[i] = k }
        }
        yerelleriTazele()
    }

    func kuluckaSil(_ id: String) async throws {
        try yazilabilir()
        try await sil("kuluckalar", id)
        veri.kuluckalar.removeAll { $0.id == id }
        yerelleriTazele()
    }

    /// Çıkımı kaydeder; `yeniUniteAdi` doluysa önce ünite oluşturulur. Toplam civcivi döner.
    @discardableResult
    func cikimKaydet(kuluckaId: String, satirlar: [CikimKaynagi], tarih: String, not: String,
                     uniteId: String?, yeniUniteAdi: String?, yeniUniteTipi: UniteTipi) async throws -> (Int, String?) {
        try yazilabilir()
        var hedef = uniteId
        let toplam = satirlar.reduce(0) { $0 + $1.civciv }
        if let ad = yeniUniteAdi?.trimmingCharacters(in: .whitespaces), !ad.isEmpty, toplam > 0 {
            hedef = try await uniteEkle(ad: ad, tip: yeniUniteTipi, adet: 0, tarih: tarih)
        }
        var v = veri
        let degisen = try v.cikimKaydet(kuluckaId: kuluckaId, satirlar: satirlar, tarih: tarih, not: not, uniteId: hedef)
        if let degisen, let u = v.unite(degisen) { try await uniteYaz(u) }
        if let k = v.kuluckalar.first(where: { $0.id == kuluckaId }) { try await guncelle("kuluckalar", k.id, k.satir) }
        veri = v
        yerelleriTazele()
        return (toplam, degisen.flatMap { v.unite($0)?.ad })
    }

    // MARK: Satış

    func satisKaydet(eskiId: String?, musteri: String, tarih: String, urunler: [SatisUrunu], odenen: Double?, not: String) async throws {
        try yazilabilir()
        let eski = eskiId.flatMap { id in veri.satislar.first { $0.id == id } }
        try veri.satisDogrula(urunler, eski: eski)
        var u = urunler
        let toplam = u.reduce(0.0) { r, x in
            let adet = x.tip == .hayvan ? x.erkekAdet + x.disiAdet : x.adet
            return r + Double(adet) * x.fiyat
        }
        let ode = odenen ?? toplam
        guard ode >= 0 else { throw KuralHatasi("Ödenen tutar geçersiz!") }
        guard ode <= toplam + 0.001 else {
            throw KuralHatasi("Ödenen tutar (\(para(ode))) satış toplamını (\(para(toplam))) geçemez!")
        }
        let mus = musteri.trimmingCharacters(in: .whitespaces)
        var v = veri
        let d = v.satisUygula(&u, eski: eski, musteri: mus, tarih: tarih)
        for id in d.kumesler { if let k = v.kumes(id) { try await kumesYaz(k) } }
        for id in d.uniteler { if let x = v.unite(id) { try await uniteYaz(x) } }
        let n = not.trimmingCharacters(in: .whitespaces)
        var s = Satis(id: eski?.id ?? "", musteri: mus.isEmpty ? nil : mus, tarih: tarih, urunler: u,
                      toplam: toplam, odenen: min(ode, toplam), not: n.isEmpty ? nil : n)
        if let eski {
            try await guncelle("satislar", eski.id, s.satir)
            if let i = v.satislar.firstIndex(where: { $0.id == eski.id }) { v.satislar[i] = s }
        } else {
            s.id = try await ekle("satislar", s.satir)
            v.satislar.insert(s, at: 0)
        }
        veri = v
    }

    func satisSil(_ id: String) async throws {
        try yazilabilir()
        guard let s = veri.satislar.first(where: { $0.id == id }) else { return }
        var v = veri
        let d = v.satisStokIade(s, notOnEk: "Satış iptali")
        for kid in d.kumesler { if let k = v.kumes(kid) { try await kumesYaz(k) } }
        for uid in d.uniteler { if let u = v.unite(uid) { try await uniteYaz(u) } }
        try await sil("satislar", id)
        v.satislar.removeAll { $0.id == id }
        veri = v
    }

    /// Kalan alacağı tahsil edildi say (web `satisBorcAl`).
    func tahsilEt(_ id: String) async throws {
        try yazilabilir()
        guard var s = veri.satislar.first(where: { $0.id == id }) else { return }
        s.odenen = s.toplam
        try await guncelle("satislar", id, s.satir)
        if let i = veri.satislar.firstIndex(where: { $0.id == id }) { veri.satislar[i] = s }
    }

    // MARK: Gider

    func giderKaydet(_ g: Gider) async throws {
        try yazilabilir()
        guard g.tutar > 0 else { throw KuralHatasi("Geçerli tutar girin!") }
        guard g.odenen >= 0 else { throw KuralHatasi("Ödenen tutar geçersiz!") }
        guard g.odenen <= g.tutar + 0.001 else {
            throw KuralHatasi("Ödenen tutar (\(para(g.odenen))) gider tutarını (\(para(g.tutar))) geçemez!")
        }
        var g = g
        g.odenen = min(g.odenen, g.tutar)
        if g.id.isEmpty {
            g.id = try await ekle("giderler", g.satir)
            veri.giderler.insert(g, at: 0)
        } else {
            try await guncelle("giderler", g.id, g.satir)
            if let i = veri.giderler.firstIndex(where: { $0.id == g.id }) { veri.giderler[i] = g }
        }
    }

    func giderSil(_ id: String) async throws {
        try yazilabilir()
        try await sil("giderler", id)
        veri.giderler.removeAll { $0.id == id }
    }

    func borcOde(_ id: String) async throws {
        try yazilabilir()
        guard var g = veri.giderler.first(where: { $0.id == id }) else { return }
        g.odenen = g.tutar
        try await guncelle("giderler", id, g.satir)
        if let i = veri.giderler.firstIndex(where: { $0.id == id }) { veri.giderler[i] = g }
    }

    // MARK: Sezon arşivi

    func sezonlariYukle() async {
        guard let uid = kullanici else { return }
        do {
            let r: [JSONNesne] = try await supabase.from("sezonlar").select("id, ad, tarih, veri").eq("user_id", value: uid)
                .order("created_at", ascending: false).execute().value
            sezonlar = r.map(Sezon.init(satir:))
        } catch {
            sezonlar = []
        }
    }

    func sezonGor(_ s: Sezon) {
        arsiv = s
        veri = s.anlikVeri
    }

    func canliyaDon() async {
        arsiv = nil
        await yukle()
    }

    func sezonSil(_ id: String) async throws {
        guard let uid = kullanici else { return }
        try await supabase.from("sezonlar").delete(returning: .minimal).eq("id", value: id).eq("user_id", value: uid).execute()
        sezonlar.removeAll { $0.id == id }
    }

    private func arsivle(ad: String) async throws {
        guard let uid = kullanici else { throw KuralHatasi("Oturum bulunamadı.") }
        let satir: JSONNesne = ["id": .metin(yeniKimlik()), "user_id": .metin(uid), "ad": .metin(ad),
                                "tarih": .metin(Gun.bugun), "veri": .nesne(veri.bellek)]
        try await supabase.from("sezonlar").insert(satir, returning: .minimal).execute()
    }

    /// Yeni sezon (web `yeniSezonOlustur`): arşivle, satış/gider ve tamamlanmış kuluçkaları sil.
    func yeniSezon(ad: String) async throws {
        try yazilabilir()
        guard let uid = kullanici else { return }
        try await arsivle(ad: ad)
        do {
            try await supabase.from("satislar").delete(returning: .minimal).eq("user_id", value: uid).execute()
            try await supabase.from("giderler").delete(returning: .minimal).eq("user_id", value: uid).execute()
        } catch {
            throw KuralHatasi("Arşiv kaydedildi ama satış/giderler silinemedi: \(error.localizedDescription)")
        }
        for k in veri.biten { try await sil("kuluckalar", k.id) }
        await yukle()
    }

    /// Yıl sonu (web `yeniDonemeGec`): önce arşiv, sonra devredenler eklenir, eski kayıtlar id ile silinir.
    func yilSonu(alacakDevret: Bool, borcDevret: Bool, bitenKuluckalariSil: Bool) async throws -> String {
        try yazilabilir()
        do { try await arsivle(ad: "Yıl Sonu " + Gun.goster(Date())) } catch {
            throw KuralHatasi("Arşiv kaydedilemedi, hiçbir şey silinmedi: \(error.localizedDescription)")
        }
        let dev = veri.devredenler(alacak: alacakDevret, borc: borcDevret)
        let eskiS = veri.satislar.map(\.id), eskiG = veri.giderler.map(\.id)
        var silinenKulucka = 0
        if bitenKuluckalariSil {
            for k in veri.biten { try await sil("kuluckalar", k.id); silinenKulucka += 1 }
        }
        for s in dev.satislar { _ = try await ekle("satislar", s.satir) }
        for g in dev.giderler { _ = try await ekle("giderler", g.satir) }
        if !eskiS.isEmpty {
            try await supabase.from("satislar").delete(returning: .minimal).in("id", values: eskiS).execute()
        }
        if !eskiG.isEmpty {
            try await supabase.from("giderler").delete(returning: .minimal).in("id", values: eskiG).execute()
        }
        await yukle()
        var m = "Kümesler ve hayvanlar korundu."
        if silinenKulucka > 0 { m += "\n\(silinenKulucka) tamamlanmış kuluçka silindi." }
        if !dev.satislar.isEmpty { m += "\n\(dev.satislar.count) alacak aktarıldı." }
        if !dev.giderler.isEmpty { m += "\n\(dev.giderler.count) borç aktarıldı." }
        return m
    }
}
