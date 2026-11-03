import SwiftUI
import UIKit
import UserNotifications
import WidgetKit
import KumesCekirdek

/// Ana ekran widget'ına veri: App Group'a `kp_widget` (web `widgetGuncelle` ile aynı JSON), sonra yenile.
enum WidgetKoprusu {
    static func yaz(_ json: String) {
        let d = UserDefaults(suiteName: Sabitler.appGroup)
        guard d?.string(forKey: "kp_widget") != json else { return }
        d?.set(json, forKey: "kp_widget")
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Çıkışta önceki hesabın kuluçkaları ana ekranda kalmasın.
    static func temizle() {
        UserDefaults(suiteName: Sabitler.appGroup)?.removeObject(forKey: "kp_widget")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Kuluçka hatırlatmaları — cihazda kurulan yerel bildirimler (APNs yok). Android ile aynı kapsam.
@MainActor
enum YerelBildirim {
    private static let onEk = "kp-"
    private static let soruldu = "kp_bildirim_soruldu"

    static func durum() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    static func izinIste() async -> Bool {
        UserDefaults.standard.set(true, forKey: soruldu)
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func bekleyenSayisi() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().filter { $0.identifier.hasPrefix(onEk) }.count
    }

    /// Bizim kurduklarımızı silip planı yeniden kurar. İzin hiç sorulmadıysa ve aktif kuluçka varsa bir kez sorar.
    static func kur(_ plan: [PlanliBildirim]) async {
        let merkez = UNUserNotificationCenter.current()
        var d = await durum()
        if d == .notDetermined, !plan.isEmpty, !UserDefaults.standard.bool(forKey: soruldu) {
            _ = await izinIste()
            d = await durum()
        }
        let eski = await merkez.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(onEk) }
        merkez.removePendingNotificationRequests(withIdentifiers: eski)
        guard d == .authorized || d == .provisional || d == .ephemeral else { return }
        for b in plan {
            let icerik = UNMutableNotificationContent()
            icerik.title = b.baslik
            icerik.body = b.metin
            icerik.sound = .default
            let bilesen = Gun.takvim.dateComponents([.year, .month, .day, .hour, .minute], from: b.zaman)
            let tetik = UNCalendarNotificationTrigger(dateMatching: bilesen, repeats: false)
            try? await merkez.add(UNNotificationRequest(identifier: b.kimlik, content: icerik, trigger: tetik))
        }
    }

    static func hepsiniSil() {
        let merkez = UNUserNotificationCenter.current()
        merkez.getPendingNotificationRequests { r in
            merkez.removePendingNotificationRequests(withIdentifiers: r.map(\.identifier).filter { $0.hasPrefix("kp-") })
        }
    }
}

/// Uygulama içi yönlendirme: ikon menüsü, bildirim dokunuşu.
enum Kisayol: String {
    case satis = "com.kamilsaim.kumespro.satis"
    case gider = "com.kamilsaim.kumespro.gider"
    case kulucka = "com.kamilsaim.kumespro.kulucka"
}

final class UygulamaDelegesi: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Uygulama açıkken de bildirim şeridi görünsün.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler tamam: @escaping (UNNotificationPresentationOptions) -> Void) {
        tamam([.banner, .sound, .list])
    }

    // Kuluçka hatırlatmasına dokununca Kuluçka sekmesi.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler tamam: @escaping () -> Void) {
        Task { @MainActor in Gezinti.ortak.bekleyenSekme = .kulucka }
        tamam()
    }

    func application(_ application: UIApplication, configurationForConnecting sahne: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let k = options.shortcutItem { Task { @MainActor in Gezinti.ortak.kisayol(k.type) } }
        let y = UISceneConfiguration(name: nil, sessionRole: sahne.role)
        y.delegateClass = SahneDelegesi.self
        return y
    }
}

/// Uygulama açıkken / arka plandayken ikon menüsünden seçilen öğe.
final class SahneDelegesi: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            Gezinti.ortak.kisayol(shortcutItem.type)
            completionHandler(true)
        }
    }
}

/// Hafif titreşim.
enum Titresim {
    @MainActor static func basari() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    @MainActor static func hata() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    @MainActor static func dokun() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
