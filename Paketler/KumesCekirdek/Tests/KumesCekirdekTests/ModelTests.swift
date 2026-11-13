import XCTest
@testable import KumesCekirdek

func cozJSON(_ s: String) -> JSONNesne {
    try! JSONDecoder().decode([String: JSON].self, from: Data(s.utf8))
}

final class ModelTests: XCTestCase {
    func testBuyukJSONSayisiTamSayiyaDonusturulurkenCokmez() {
        XCTAssertNil(JSON.sayi(1e100).int)
        XCTAssertEqual(JSON.sayi(1e100).string, String(1e100))
    }
    func testJSONGidisDonusTanimadikAlanlariKorur() throws {
        let r = cozJSON(#"{"id":"k1","ad":"Büyük","tur":"tavuk","not_":null,"irklar":[{"id":"x1","ad":"Brahma","erkek":3,"disi":5,"renk":"sari"}],"hareketler":[]}"#)
        var k = Kumes(satir: r)
        XCTAssertEqual(k.toplam, 8)
        k.irklar[0].erkek += 1
        let yazilan = k.satir
        let irk = yazilan["irklar"]?.dizi?.first?.nesne
        XCTAssertEqual(irk?["renk"], .metin("sari"))
        XCTAssertEqual(irk?["erkek"]?.int, 4)
    }

    func testTamSayiTamSayiOlarakYazilir() throws {
        let d = try JSONEncoder().encode(JSON.s(3))
        XCTAssertEqual(String(decoding: d, as: UTF8.self), "3")
        let b = try JSONDecoder().decode(JSON.self, from: Data("true".utf8))
        XCTAssertEqual(b, .bool(true))
        let n = try JSONDecoder().decode(JSON.self, from: Data("1".utf8))
        XCTAssertEqual(n, .sayi(1))
    }

    func testIrkKimligiYoksaUretilir() {
        let i = Irk(ham: ["ad": .metin("Genel")])
        XCTAssertFalse(i.id.isEmpty)
    }

    func testUniteMetaTipiOkunurVeYazilir() {
        let r = cozJSON(#"{"id":"u1","ad":"Ünite","adet":5,"hareketler":[{"_meta":true,"tip":"yavru_guvercin"},{"islem":"ekle","partiId":"p1","adet":5,"kalan":5,"kaynak":"A","tarih":"2026-10-01"}]}"#)
        let u = Unite(satir: r)
        XCTAssertEqual(u.tip, .yavruGuvercin)
        XCTAssertEqual(u.hareketler.count, 1)
        XCTAssertFalse(u.gocGerekli)
        let ilk = u.satir["hareketler"]?.dizi?.first?.nesne
        XCTAssertEqual(ilk?["_meta"], .bool(true))
        XCTAssertEqual(ilk?["tip"], .metin("yavru_guvercin"))
    }

    func testEskiUniteGocu() {
        // partiId/kalan yok; eski çıkar FIFO düşülür, adet parti toplamına eşitlenir
        let r = cozJSON(#"{"id":"u1","ad":"Ü","adet":99,"hareketler":[{"islem":"ekle","adet":10,"tarih":"2026-01-01","not":"Kuluçka — Brahma"},{"islem":"ekle","adet":4,"tarih":"2026-02-01"},{"islem":"cikar","adet":12,"tarih":"2026-03-01"}]}"#)
        let u = Unite(satir: r)
        XCTAssertTrue(u.gocGerekli)
        XCTAssertEqual(u.hareketler[0].kalan, 0)
        XCTAssertEqual(u.hareketler[1].kalan, 2)
        XCTAssertEqual(u.hareketler[0].kaynak, "Brahma")
        XCTAssertEqual(u.hareketler[1].kaynak, "Genel")
        XCTAssertEqual(u.adet, 2)
        XCTAssertNotNil(u.hareketler[0].partiId)
    }

    func testSatisOdenenYoksaTamamiOdenmis() {
        let s = Satis(satir: cozJSON(#"{"id":"s1","tarih":"2026-11-01","urunler":[],"toplam":"150.5","odenen":null}"#))
        XCTAssertEqual(s.toplam, 150.5)
        XCTAssertEqual(s.kalan, 0)
        XCTAssertEqual(s.musteriAdi, "Anonim")
    }

    func testEskiHayvanUrunuErkekDisiyeBolunur() {
        let u = SatisUrunu(ham: ["tip": .metin("hayvan"), "adet": .s(5)])
        XCTAssertEqual(u.erkekAdet, 2)
        XCTAssertEqual(u.disiAdet, 3)
    }

    func testBellekBicimi() {
        let g = Gider(id: "g1", tur: "yem", aciklama: nil, tutar: 100, tarih: "2026-11-02", kumesId: "k1", odenen: 40)
        XCTAssertEqual(g.bellek["kumesId"], .metin("k1"))
        XCTAssertEqual(g.bellek["kalan"]?.double, 60)
        let geri = Gider(bellek: g.bellek)
        XCTAssertEqual(geri, g)
        let ku = Kulucka(id: "q", ad: "A", baslangic: "2026-10-01", sure: 21, kaynaklar: [YumurtaKaynagi(kumesId: nil, adet: 12)], not: "n")
        XCTAssertEqual(ku.bellek["toplamYumurta"]?.int, 12)
        XCTAssertEqual(Kulucka(bellek: ku.bellek).not, "n")
    }
}
