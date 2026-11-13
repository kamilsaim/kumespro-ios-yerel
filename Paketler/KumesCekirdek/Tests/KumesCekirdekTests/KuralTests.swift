import XCTest
@testable import KumesCekirdek

final class KuralTests: XCTestCase {
    func testSatilanPartiSilinemezVeIadeAsilPartiyeDoner() throws {
        var v = ornek()
        var c = SatisUrunu.yeni(tip: .civciv, kumesId: nil, irkId: nil, uniteId: "u1")
        c.partiId = "p1"; c.adet = 5; c.fiyat = 20
        var urunler = [c]
        try v.satisDogrula(urunler, eski: nil)
        _ = v.satisUygula(&urunler, eski: nil, musteri: "Deneme", tarih: "2026-11-13")
        let s = Satis(id: "s1", musteri: "Deneme", tarih: "2026-11-13", urunler: urunler,
                      toplam: 100, odenen: 0, not: nil)
        v.satislar = [s]
        XCTAssertThrowsError(try v.partiSil(uniteId: "u1", partiId: "p1"))
        XCTAssertEqual(v.uniteler[0].adet, 25)
        _ = v.satisStokIade(s, notOnEk: "İptal")
        XCTAssertEqual(v.uniteler[0].adet, 30)
        XCTAssertEqual(v.uniteler[0].parti("p1")?.kalan, 30)
    }

    func testAyniStokBirdenFazlaSatirdaAsilamaz() throws {
        let v = ornek()
        XCTAssertThrowsError(try v.satisDogrula([hayvan(6, 0), hayvan(6, 0)], eski: nil))
        try v.satisDogrula([hayvan(6, 0), hayvan(4, 0)], eski: nil)
        var c = SatisUrunu.yeni(tip: .civciv, kumesId: nil, irkId: nil, uniteId: "u1")
        c.partiId = "p1"; c.adet = 20; c.fiyat = 10
        XCTAssertThrowsError(try v.satisDogrula([c, c], eski: nil))
    }

    func testDuzenlemeKredisiHerSatirIcinTekrarKullanilamaz() throws {
        var v = ornek()
        var urunler = [hayvan(10, 0)]
        _ = v.satisUygula(&urunler, eski: nil, musteri: nil, tarih: "2026-11-13")
        let eski = Satis(id: "s1", musteri: nil, tarih: "2026-11-13", urunler: urunler,
                         toplam: 1000, odenen: 0, not: nil)
        XCTAssertThrowsError(try v.satisDogrula([hayvan(6, 0), hayvan(6, 0)], eski: eski))
    }

    func testTamamlananCikimTekrarStokEklemez() throws {
        var v = ornek()
        v.kuluckalar = [Kulucka(id: "q", ad: "Test", baslangic: "2026-11-01", sure: 21,
                               kaynaklar: [YumurtaKaynagi(kumesId: "k1", adet: 5)])]
        var satirlar = v.cikimSatirlari(kuluckaId: "q")
        satirlar[0].civciv = 4; satirlar[0].bos = 1
        _ = try v.cikimKaydet(kuluckaId: "q", satirlar: satirlar, tarih: "2026-11-22", not: "", uniteId: "u1")
        XCTAssertThrowsError(try v.cikimKaydet(kuluckaId: "q", satirlar: satirlar,
                                             tarih: "2026-11-22", not: "", uniteId: "u1"))
        XCTAssertEqual(v.uniteler[0].adet, 34)
    }

    func ornek() -> Veri {
        var k = Kumes(id: "k1", ad: "Büyük", tur: "tavuk")
        k.irklar = [Irk(ad: "Brahma", erkek: 10, disi: 20, id: "r1"), Irk(ad: "Sussex", erkek: 2, disi: 3, id: "r2")]
        var u = Unite(id: "u1", ad: "Ünite", tip: .civciv)
        var p = UniteHareketi.parti(adet: 30, kaynak: "Brahma", not: "", tarih: "2026-10-01")
        p.ham["partiId"] = .metin("p1")
        u.hareketler = [p]
        u.adet = 30
        return Veri(kumesler: [k], uniteler: [u])
    }

    func hayvan(_ e: Int, _ d: Int, fiyat: Double = 100, irk: String? = "r1") -> SatisUrunu {
        var x = SatisUrunu.yeni(kumesId: "k1", irkId: irk, uniteId: nil)
        x.erkekAdet = e; x.disiAdet = d; x.fiyat = fiyat
        return x
    }

    func testHayvanEkleCikar() throws {
        var v = ornek()
        try v.hayvanIslemi(kumesId: "k1", islem: .ekle, irkId: "r2", erkek: 1, disi: 1, not: "", dogumTarihi: "2026-01-01")
        XCTAssertEqual(v.kumesler[0].irklar[1].toplam, 7)
        XCTAssertThrowsError(try v.hayvanIslemi(kumesId: "k1", islem: .cikar, irkId: "r2", erkek: 9, disi: 0, not: "", dogumTarihi: nil))
        try v.hayvanIslemi(kumesId: "k1", islem: .cikar, irkId: "r2", erkek: 3, disi: 0, not: "", dogumTarihi: nil)
        XCTAssertEqual(v.kumesler[0].irklar[1].erkek, 0)
        XCTAssertEqual(v.kumesler[0].hareketler.count, 2)
        // son hareketi silince etkisi geri alınır
        v.kumesHareketiSil(kumesId: "k1", indeks: 1)
        XCTAssertEqual(v.kumesler[0].irklar[1].erkek, 3)
    }

    func testGenelIrkYoksaOlusur() throws {
        var v = Veri(kumesler: [Kumes(id: "k", ad: "Boş", tur: "kaz")])
        try v.hayvanIslemi(kumesId: "k", islem: .ekle, irkId: nil, erkek: 2, disi: 0, not: "", dogumTarihi: nil)
        XCTAssertEqual(v.kumesler[0].irklar.first?.ad, "Genel")
        XCTAssertEqual(v.kumesler[0].toplam, 2)
    }

    func testSatisStokDuserVeIadeEder() throws {
        var v = ornek()
        var urunler = [hayvan(2, 4)]
        var c = SatisUrunu.yeni(tip: .civciv, kumesId: nil, irkId: nil, uniteId: "u1")
        c.partiId = "p1"; c.adet = 5; c.fiyat = 20
        urunler.append(c)
        try v.satisDogrula(urunler, eski: nil)
        let d = v.satisUygula(&urunler, eski: nil, musteri: "Ali", tarih: "2026-11-03")
        XCTAssertEqual(d.kumesler, ["k1"]); XCTAssertEqual(d.uniteler, ["u1"])
        XCTAssertEqual(v.kumesler[0].irklar[0].erkek, 8)
        XCTAssertEqual(v.kumesler[0].irklar[0].disi, 16)
        XCTAssertEqual(urunler[0].adet, 6)
        XCTAssertEqual(urunler[0].irkAd, "Brahma")
        XCTAssertEqual(v.uniteler[0].adet, 25)
        XCTAssertEqual(v.uniteler[0].parti("p1")?.kalan, 25)

        let s = Satis(id: "s1", musteri: "Ali", tarih: "2026-11-03", urunler: urunler, toplam: 700, odenen: 0, not: nil)
        _ = v.satisStokIade(s, notOnEk: "Satış iptali")
        XCTAssertEqual(v.kumesler[0].irklar[0].erkek, 10)
        XCTAssertEqual(v.uniteler[0].adet, 30)
        XCTAssertEqual(v.uniteler[0].parti("p1")?.kalan, 30)
        // iade kaydı ayrı parti sayılmaz → yeniden okununca stok ikiye katlanmaz
        let geri = Unite(satir: v.uniteler[0].satir.merging(["id": .metin("u1")]) { a, _ in a })
        XCTAssertEqual(geri.adet, 30)
        XCTAssertFalse(geri.gocGerekli)
    }

    func testStokYetmezseHata() {
        let v = ornek()
        XCTAssertThrowsError(try v.satisDogrula([hayvan(11, 0)], eski: nil))
        XCTAssertThrowsError(try v.satisDogrula([hayvan(1, 0, irk: nil)], eski: nil))
        XCTAssertThrowsError(try v.satisDogrula([hayvan(1, 0, fiyat: 0)], eski: nil))
        XCTAssertThrowsError(try v.satisDogrula([], eski: nil))
    }

    func testDuzenlemedeEskiAdetKrediSayilir() throws {
        var v = ornek()
        var urunler = [hayvan(10, 0)]
        try v.satisDogrula(urunler, eski: nil)
        _ = v.satisUygula(&urunler, eski: nil, musteri: nil, tarih: "2026-11-03")
        XCTAssertEqual(v.kumesler[0].irklar[0].erkek, 0)
        let eski = Satis(id: "s1", musteri: nil, tarih: "2026-11-03", urunler: urunler, toplam: 1000, odenen: 0, not: nil)
        // yalnız fiyat değişti → stoğa dokunulmaz
        var yeni = urunler
        yeni[0].fiyat = 150
        try v.satisDogrula(yeni, eski: eski)
        let d = v.satisUygula(&yeni, eski: eski, musteri: nil, tarih: "2026-11-04")
        XCTAssertEqual(d, Degisenler())
        XCTAssertEqual(v.kumesler[0].irklar[0].erkek, 0)
        // adet 10 → 8: önce 10 iade, sonra 8 düşülür
        var az = urunler
        az[0].erkekAdet = 8
        try v.satisDogrula(az, eski: eski)
        _ = v.satisUygula(&az, eski: eski, musteri: nil, tarih: "2026-11-04")
        XCTAssertEqual(v.kumesler[0].irklar[0].erkek, 2)
    }

    func testPartiIslemleri() throws {
        var v = ornek()
        try v.partidenCikar(uniteId: "u1", partiId: "p1", adet: 3, not: "", tarih: "2026-11-03")
        XCTAssertEqual(v.uniteler[0].adet, 27)
        XCTAssertEqual(v.uniteler[0].hareketler.last?.not, "Ölüm/Kayıp")
        XCTAssertThrowsError(try v.partidenCikar(uniteId: "u1", partiId: "p1", adet: 100, not: "", tarih: "2026-11-03"))
        try v.partiDuzenle(uniteId: "u1", partiId: "p1", kaynak: "", adet: 30, kalan: 40, tarih: "2026-10-01", not: "")
        XCTAssertEqual(v.uniteler[0].parti("p1")?.kalan, 30)
        XCTAssertEqual(v.uniteler[0].adet, 30)
        XCTAssertEqual(v.uniteler[0].parti("p1")?.kaynak, "Genel")
        try v.partiEkle(uniteId: "u1", adet: 5, kaynak: "Sussex", not: "", tarih: "2026-11-01")
        XCTAssertEqual(v.uniteler[0].adet, 35)
        try v.partiSil(uniteId: "u1", partiId: "p1")
        XCTAssertEqual(v.uniteler[0].adet, 5)
    }

    func testKumeseAktar() throws {
        var v = ornek()
        let d = try v.kumeseAktar(uniteId: "u1", partiId: "p1", kumesId: "k1", irkId: nil, yeniIrkAdi: "",
                                  erkek: 4, disi: 6, not: "", tarih: "2026-11-03")
        XCTAssertEqual(d.kumesler, ["k1"])
        XCTAssertEqual(v.uniteler[0].adet, 20)
        // parti kaynağı "Brahma" → aynı adlı ırka eklenir
        XCTAssertEqual(v.kumesler[0].irklar[0].erkek, 14)
        XCTAssertEqual(v.kumesler[0].hareketler.last?.dogumTarihi, "2026-10-01")
        XCTAssertThrowsError(try v.kumeseAktar(uniteId: "u1", partiId: "p1", kumesId: "k1", irkId: "r2", yeniIrkAdi: nil,
                                               erkek: 30, disi: 0, not: "", tarih: "2026-11-03"))
    }

    func testCikimKaydi() throws {
        var v = ornek()
        let ku = Kulucka(id: "q1", ad: "Mart", baslangic: "2026-10-01", sure: 21,
                         kaynaklar: [YumurtaKaynagi(kumesId: "k1", adet: 10), YumurtaKaynagi(kumesId: nil, adet: 5, aciklama: "Komşu")])
        v.kuluckalar = [ku]
        var satirlar = v.cikimSatirlari(kuluckaId: "q1")
        XCTAssertEqual(satirlar.map(\.ad), ["Büyük", "Komşu"])
        satirlar[0].civciv = 8; satirlar[0].olu = 1; satirlar[0].bos = 1
        satirlar[1].civciv = 3
        let degisen = try v.cikimKaydet(kuluckaId: "q1", satirlar: satirlar, tarih: "2026-10-22", not: "", uniteId: "u1")
        XCTAssertEqual(degisen, "u1")
        XCTAssertTrue(v.kuluckalar[0].tamamlandi)
        XCTAssertEqual(v.kuluckalar[0].cikim?.civciv, 11)
        XCTAssertEqual(v.uniteler[0].adet, 41)
        XCTAssertEqual(v.uniteler[0].aktifPartiler.count, 3)
        XCTAssertEqual(v.kuluckalar[0].verim, 73)
        // tekrar açılınca eski değerler gelir
        XCTAssertEqual(v.cikimSatirlari(kuluckaId: "q1")[0].civciv, 8)
    }

    func testFinansVeAlacaklar() {
        var v = Veri()
        v.satislar = [
            Satis(id: "1", musteri: "Ali", tarih: "2026-11-01", urunler: [], toplam: 100, odenen: 40, not: nil),
            Satis(id: "2", musteri: " Ali ", tarih: "2026-10-01", urunler: [], toplam: 50, odenen: 0, not: nil),
            Satis(id: "3", musteri: nil, tarih: "2026-11-02", urunler: [], toplam: 30, odenen: 30, not: nil)
        ]
        v.giderler = [Gider(id: "g", tur: "yem", aciklama: nil, tutar: 70, tarih: "2026-11-05", kumesId: nil, odenen: 20)]
        let o = v.finansOzeti()
        XCTAssertEqual(o.gelir, 180); XCTAssertEqual(o.gider, 70); XCTAssertEqual(o.net, 110)
        XCTAssertEqual(o.alacak, 110); XCTAssertEqual(o.borc, 50)
        XCTAssertEqual(v.alacaklar.count, 1)
        XCTAssertEqual(v.alacaklar.first?.toplam, 110)
        XCTAssertEqual(v.finansOzeti(ay: "2026-11").gelir, 130)
        XCTAssertEqual(v.aylar, ["2026-11", "2026-10"])
        let dev = v.devredenler(alacak: true, borc: true, bugun: "2027-01-01")
        XCTAssertEqual(dev.satislar.count, 2)
        XCTAssertEqual(dev.satislar[0].toplam, 60)
        XCTAssertEqual(dev.giderler.first?.tutar, 50)
    }
}
