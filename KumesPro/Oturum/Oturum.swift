import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Supabase
import KumesCekirdek

/// Supabase oturumu. Apple ile giriş yerel pencereyle, Google sistem tarayıcı oturumuyla.
@Observable @MainActor
final class Oturum {
    private(set) var kullanici: User?
    /// Kayıtlı oturum diskten okundu (ilk olay geldi).
    private(set) var hazir = false

    @ObservationIgnored private var appleNonce: String?
    @ObservationIgnored private var dinleniyor = false

    var kullaniciId: String? { kullanici?.id.uuidString.lowercased() }

    var gorunum: HesapGorunum {
        let md = kullanici?.userMetadata ?? [:]
        var ad: String?
        for a in ["full_name", "name"] { if case let .string(s)? = md[a], !s.isEmpty { ad = s; break } }
        var saglayici: String?
        if case let .string(s)? = kullanici?.appMetadata["provider"] { saglayici = s }
        return HesapGorunum(eposta: kullanici?.email, adSoyad: ad, saglayici: saglayici)
    }

    /// Son JSON yedeğinin kaç gün önce alındığı (user_metadata.son_yedek, tüm cihazlarda ortak).
    var yedekGunOnce: Int? {
        guard case let .string(s)? = kullanici?.userMetadata["son_yedek"] else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        return d.map { max(0, Int(Date().timeIntervalSince($0) / 86400)) }
    }

    func baslat() async {
        guard !dinleniyor else { return }
        dinleniyor = true
        for await (_, oturum) in supabase.auth.authStateChanges {
            let yeni = oturum?.user
            if yeni == nil, kullanici != nil {
                WidgetKoprusu.temizle()
                YerelBildirim.hepsiniSil()
            }
            kullanici = yeni
            hazir = true
        }
    }

    // MARK: Apple

    func appleIstegiHazirla(_ istek: ASAuthorizationAppleIDRequest) {
        let nonce = Self.rastgeleNonce()
        appleNonce = nonce
        istek.requestedScopes = [.fullName, .email]
        istek.nonce = Self.sha256(nonce)
    }

    func appleSonucu(_ sonuc: Result<ASAuthorization, Error>) async throws {
        switch sonuc {
        case .failure(let hata):
            if (hata as? ASAuthorizationError)?.code == .canceled { return }
            throw hata
        case .success(let yetki):
            guard let k = yetki.credential as? ASAuthorizationAppleIDCredential,
                  let jv = k.identityToken, let jeton = String(data: jv, encoding: .utf8),
                  let nonce = appleNonce
            else { throw KuralHatasi("Apple girişinden bilgi alınamadı. Lütfen tekrar deneyin.") }
            try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: jeton, nonce: nonce))
            // Apple yalnız ilk girişte ad verir — hesap kartında görünsün
            let ad = [k.fullName?.givenName, k.fullName?.familyName].compactMap { $0 }
                .joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !ad.isEmpty {
                _ = try? await supabase.auth.update(user: UserAttributes(data: ["full_name": .string(ad)]))
                kullanici = try? await supabase.auth.user()
            }
            // Hesap silinirken Apple jetonu iptal edilebilsin (App Store 5.1.1(v)): yetki kodu sunucuya
            if let kv = k.authorizationCode, let kod = String(data: kv, encoding: .utf8) {
                Task {
                    do { try await supabase.functions.invoke("apple-jeton", options: FunctionInvokeOptions(body: ["kod": kod])) }
                    catch { print("apple-jeton:", error) }
                }
            }
        }
    }

    // MARK: Google

    func googleIleGir() async throws {
        do {
            try await supabase.auth.signInWithOAuth(provider: .google, redirectTo: Sabitler.girisDonusu)
        } catch let h as ASWebAuthenticationSessionError where h.code == .canceledLogin {
            return
        }
    }

    // MARK: Hesap

    /// JSON yedeği alındı — tarih hesaba yazılır (web ile aynı alan).
    func yedekAlindi() async {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let u = try? await supabase.auth.update(user: UserAttributes(data: ["son_yedek": .string(f.string(from: Date()))])) {
            kullanici = u
        }
    }

    private struct SilCevabi: Decodable { let ok: Bool?; let error: String? }

    /// Hesabı ve tüm veriyi siler (Edge Function `hesap-sil`), sonra çıkış.
    func hesabiSil() async throws {
        do {
            let c: SilCevabi = try await supabase.functions.invoke("hesap-sil", options: FunctionInvokeOptions(body: [String: String]()))
            guard c.ok == true else { throw KuralHatasi(c.error ?? "Hesap silinemedi. Lütfen tekrar deneyin.") }
        } catch let FunctionsError.httpError(_, veri) {
            let m = (try? JSONDecoder().decode(SilCevabi.self, from: veri))?.error
            throw KuralHatasi(m ?? "Hesap silinemedi. Lütfen tekrar deneyin.")
        }
        await cikis()
    }

    func cikis() async {
        try? await supabase.auth.signOut()
    }

    private static func rastgeleNonce(_ uzunluk: Int = 32) -> String {
        let harfler = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<uzunluk).map { _ in harfler.randomElement()! })
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
