import XCTest
@testable import KumesCekirdek

final class HesapTests: XCTestCase {
    func gun(_ s: String) -> Date { Gun.coz(s)! }

    func testKuluckaDurumu() {
        let k = Kulucka(id: "a", ad: "A", baslangic: "2026-10-18", sure: 21, kaynaklar: [])
        let d = k.durum(bugun: gun("2026-11-02"))
        XCTAssertEqual(d.gecen, 15); XCTAssertEqual(d.kalan, 6); XCTAssertEqual(d.yuzde, 71)
        XCTAssertEqual(d.gecikme, -6)
        XCTAssertEqual(Gun.metin(d.cikim!), "2026-11-08")
        XCTAssertEqual(Gun.metin(d.sepet!), "2026-11-05")
        let g = k.durum(bugun: gun("2026-11-11"))
        XCTAssertEqual(g.gecikme, 3); XCTAssertTrue(g.gecikti); XCTAssertEqual(g.kalan, 0)
    }

    func testUyariSirasi() {
        var v = Veri()
        v.kuluckalar = [
            Kulucka(id: "1", ad: "Yakın", baslangic: "2026-10-14", sure: 21, kaynaklar: []),  // çıkım 4 Kas → 2 gün
            Kulucka(id: "2", ad: "Geç", baslangic: "2026-10-01", sure: 21, kaynaklar: []),    // çıkım 22 Eki → 11 gün gecikti
            Kulucka(id: "3", ad: "Uzak", baslangic: "2026-11-01", sure: 21, kaynaklar: [])
        ]
        let u = v.kuluckaUyarilari(bugun: gun("2026-11-02"))
        XCTAssertEqual(u.map(\.kuluckaId), ["2", "1"])
        XCTAssertEqual(u[1].baslik, "Yakın — 2 gün sonra çıkım")
        XCTAssertEqual(v.siradakiKulucka(bugun: gun("2026-11-02"))?.id, "2")
    }

    func testBildirimPlani() {
        var v = Veri()
        v.kuluckalar = [Kulucka(id: "1", ad: "A", baslangic: "2026-10-18", sure: 21, kaynaklar: [])]
        let plan = v.bildirimPlani(simdi: gun("2026-11-06"))
        // sepet 5 Kas geçti → çıkım 8 Kas + gecikme 10 Kas
        XCTAssertEqual(plan.map(\.kimlik), ["kp-1-cikim", "kp-1-gecikme"])
        XCTAssertEqual(Gun.takvim.component(.hour, from: plan[0].zaman), 8)
    }

    func testWidgetJSON() {
        var v = Veri()
        v.kuluckalar = [Kulucka(id: "1", ad: "A", baslangic: "2026-10-18", sure: 21, kaynaklar: [YumurtaKaynagi(kumesId: nil, adet: 24)]),
                        Kulucka(id: "2", ad: "B", baslangic: "2026-10-18", sure: 21, kaynaklar: [], durum: "tamamlandi")]
        XCTAssertEqual(v.widgetJSON, #"{"k":[{"ad":"A","bas":"2026-10-18","sure":21,"yum":24}]}"#)
    }

    func testBicimler() {
        XCTAssertEqual(para(1234.5), "₺1.234,50")
        XCTAssertEqual(para(12450), "₺12.450")
        XCTAssertEqual(para(-850), "−₺850")
        XCTAssertEqual(para(0, kurusZorunlu: true), "₺0,00")
        XCTAssertEqual(ondalikCoz("1.250,5"), 1250.5)
        XCTAssertEqual(ondalikCoz("12.5"), 12.5)
        XCTAssertNil(ondalikCoz(""))
        XCTAssertEqual(gunlukMetni(0), "bugün")
        XCTAssertEqual(gunlukMetni(12), "12 günlük")
        XCTAssertEqual(gunlukMetni(65), "2ay 5g")
        XCTAssertEqual(yasMetni("2025-08-01", bugun: gun("2026-11-03")), "1y 3ay")
        XCTAssertEqual(Gun.goster("2026-03-07"), "07.03.2026")
        XCTAssertEqual(Gun.kisa("2026-11-08"), "8 Kas")
        XCTAssertEqual(Gun.ayAdi("2026-11"), "Kasım 2026")
        XCTAssertEqual(Gun.uzun(gun("2026-11-03")), "3 Kasım Salı")
    }

    func testHesapGorunum() {
        let a = HesapGorunum(eposta: "abc@privaterelay.appleid.com", adSoyad: nil, saglayici: "apple")
        XCTAssertEqual(a.ad, "Apple Hesabı"); XCTAssertEqual(a.harf, "A")
        let g = HesapGorunum(eposta: "kamil@x.com", adSoyad: "Kamil", saglayici: "google")
        XCTAssertEqual(g.ad, "kamil@x.com"); XCTAssertEqual(g.harf, "K")
    }

    func testCSVVeYedek() {
        var v = Veri()
        v.satislar = [Satis(id: "1", musteri: "Ali, Veli", tarih: "2026-11-01", urunler: [], toplam: 10, odenen: 5, not: nil)]
        let r = v.csvRaporu(.tumu, bugun: "2026-11-03")
        XCTAssertEqual(r.dosya, "kumespro_tam_rapor_2026-11-03.csv")
        XCTAssertTrue(r.icerik.hasPrefix("\u{FEFF}SATISLAR"))
        XCTAssertTrue(r.icerik.contains("\"Ali, Veli\""))
        XCTAssertTrue(r.icerik.contains("Alacak,5.00"))
        let y = v.yedekJSON(eposta: "a@b.c", sezonlar: [], simdi: gun("2026-11-03"))
        XCTAssertTrue(y.dosya.hasPrefix("kumesPro_yedek_20261103_"))
        let kok = try! JSONDecoder().decode(JSON.self, from: y.veri)
        XCTAssertEqual(kok["versiyon"], .metin("5.0-cloud"))
        XCTAssertEqual(kok["veri"]?["satislar"]?.dizi?.count, 1)
        XCTAssertEqual(Veri(bellek: kok["veri"]!.nesne!).satislar.first?.musteri, "Ali, Veli")
    }

    func testOrtalamaYas() {
        var u = Unite(id: "u", ad: "U", tip: .civciv, adet: 30)
        u.hareketler = [.parti(adet: 10, kaynak: "A", not: "", tarih: "2026-10-24"),
                        .parti(adet: 20, kaynak: "B", not: "", tarih: "2026-10-31")]
        XCTAssertEqual(u.ortalamaYas(bugun: gun("2026-11-03")), 5)  // (10*10 + 3*20)/30 = 5.33
    }
}
