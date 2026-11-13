import XCTest

final class ArayuzTests: XCTestCase {
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
