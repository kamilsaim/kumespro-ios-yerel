import XCTest

final class ArayuzTests: XCTestCase {
    func testRehberSecimiVeIptalSatisFormunuKapatmaz() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--kp-arayuz-testi", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launch()
        XCTAssertTrue(app.buttons["Ekle"].waitForExistence(timeout: 30))
        app.buttons["Ekle"].tap()
        app.buttons["Satış"].tap()
        let musteri = app.textFields["Müşteri (isteğe bağlı)"]
        XCTAssertTrue(musteri.waitForExistence(timeout: 10))
        musteri.tap()
        musteri.typeText("Korunacak taslak")
        app.buttons["Rehberden seç"].tap()
        let kisi = app.staticTexts["KümesPro Test Müşteri"].firstMatch
        XCTAssertTrue(kisi.waitForExistence(timeout: 15))
        kisi.tap()
        XCTAssertTrue(app.navigationBars["Yeni satış"].waitForExistence(timeout: 10))
        XCTAssertEqual(musteri.value as? String, "KümesPro Test Müşteri")
        ekran("07-ios-rehber-secim-sonrasi-form")
        app.buttons["Rehberden seç"].tap()
        XCTAssertTrue(kisi.waitForExistence(timeout: 10))
        let kapat = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "İptal", "Vazgeç"])).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(kapat)
        kapat?.tap()
        XCTAssertTrue(app.navigationBars["Yeni satış"].waitForExistence(timeout: 10))
        XCTAssertEqual(musteri.value as? String, "KümesPro Test Müşteri")
        ekran("08-ios-rehber-iptal-sonrasi-form")
    }
    private func ekran(_ ad: String) {
        let ek = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        ek.name = ad
        ek.lifetime = .keepAlways
        add(ek)
    }

    func testSekmelerVeOrtaEkleMenusu() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--kp-arayuz-testi", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launch()
        XCTAssertTrue(app.buttons["Ekle"].waitForExistence(timeout: 30))
        ekran("01-ios-ana-ekran")
        app.buttons["Kümesler"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Örnek Brahma Kümesi"].waitForExistence(timeout: 10))
        ekran("02-ios-kumesler")
        app.buttons["Kuluçka"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Örnek kuluçka"].waitForExistence(timeout: 10))
        ekran("03-ios-kulucka")
        app.buttons["Finans"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Ekle"].exists)
        ekran("04-ios-finans")
        app.buttons["Ekle"].tap()
        XCTAssertTrue(app.staticTexts["Ne eklemek istersin?"].waitForExistence(timeout: 10))
        ekran("05-ios-orta-ekle")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Yeni kümes")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Vazgeç"].waitForExistence(timeout: 10))
        ekran("06-ios-kumes-formu")
        app.buttons["Vazgeç"].tap()
        XCTAssertTrue(app.buttons["Ekle"].waitForExistence(timeout: 10))
    }
}
