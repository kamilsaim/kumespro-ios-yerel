import XCTest
@testable import KumesCekirdek

final class GeriYukleTests: XCTestCase {
    func testGecersizListeCanliVerininYeriniAlamaz() throws {
        for json in [#"{"kumesler":null}"#, #"{"kumesler":{}}"#,
                     #"{"kumesler":[12]}"#, #"{"kumesler":[],"satislar":null}"#,
                     #"{"veri":{"kumesler":[]},"sezonArsivi":{}}"#] {
            XCTAssertThrowsError(try Yedek(dosya: Data(json.utf8)))
        }
        XCTAssertEqual(try Yedek(dosya: Data(#"{"kumesler":[]}"#.utf8)).kayitSayisi, 0)
    }

    func testYeniVeEskiBicim() throws {
        let yeni = #"{"versiyon":"5.0-cloud","tarih":"2026-11-03T10:00:00.000Z","veri":{"kumesler":[{"id":"k1","ad":"<A>","irklar":[]}],"civcivUniteleri":[{"id":"u1","ad":"Y","tip":"yavru_guvercin","adet":0,"hareketler":[]}]},"sezonArsivi":[{"ad":"S","tarih":"2026-01-01","veri":{}}]}"#
        let y = try Yedek(dosya: Data(yeni.utf8), bugun: "2026-11-04")
        XCTAssertEqual(y.veri.kumesler.first?.ad, "‹A›")
        XCTAssertEqual(y.veri.kumesler.first?.tur, "tavuk")
        XCTAssertEqual(y.veri.uniteler.first?.tip, .yavruGuvercin)
        XCTAssertEqual(y.sezonlar.count, 1)
        XCTAssertFalse((y.sezonlar[0].metin("id") ?? "").isEmpty)

        let eski = #"{"kumesler":[],"kuluckalar":[{"ad":"","toplam_yumurta":12}],"satislar":[{"toplam":100,"odenen":5000}]}"#
        let e = try Yedek(dosya: Data(eski.utf8), bugun: "2026-11-04")
        XCTAssertEqual(e.veri.kuluckalar.first?.sure, 21)
        XCTAssertEqual(e.veri.kuluckalar.first?.baslangic, "2026-11-04")
        XCTAssertEqual(e.veri.kuluckalar.first?.toplamYumurta, 12)
        XCTAssertEqual(e.veri.satislar.first?.odenen, 100)
        XCTAssertEqual(e.veri.satislar.first?.tarih, "2026-11-04")

        XCTAssertThrowsError(try Yedek(dosya: Data(#"{"a":1}"#.utf8)))
        XCTAssertThrowsError(try Yedek(dosya: Data("bozuk".utf8)))
    }

    func testKimlikEsleme() {
        var v = Veri()
        v.kuluckalar = [Kulucka(ad: "K", baslangic: "2026-11-01", sure: 21, kaynaklar: [YumurtaKaynagi(kumesId: "k1", adet: 5)])]
        v.uniteler = [Unite(id: "u1", ad: "U", tip: .civciv, hareketler: [.parti(adet: 5, kaynak: "A", not: "", tarih: "2026-11-01", kaynakKumesId: "k1")])]
        var su = SatisUrunu.yeni(tip: .civciv, kumesId: "k1", irkId: nil, uniteId: "u1")
        su.adet = 1
        v.satislar = [Satis(musteri: nil, tarih: "2026-11-02", urunler: [su], toplam: 1, odenen: 1, not: nil)]
        v.giderler = [Gider(tur: "yem", aciklama: nil, tutar: 1, tarih: "2026-11-02", kumesId: "k1", odenen: 1),
                      Gider(tur: "yem", aciklama: nil, tutar: 1, tarih: "2026-11-02", kumesId: "yok", odenen: 1)]
        v.kumesKimlikleriniEsle(["k1": "K-YENI"])
        v.uniteKimlikleriniEsle(["u1": "U-YENI"])
        XCTAssertEqual(v.kuluckalar[0].kaynaklar[0].kumesId, "K-YENI")
        XCTAssertEqual(v.uniteler[0].hareketler[0].ham.metin("kaynakKumesId"), "K-YENI")
        XCTAssertEqual(v.satislar[0].urunler[0].kumesId, "K-YENI")
        XCTAssertEqual(v.satislar[0].urunler[0].uniteId, "U-YENI")
        XCTAssertEqual(v.giderler[0].kumesId, "K-YENI")
        XCTAssertNil(v.giderler[1].kumesId)
    }
}
