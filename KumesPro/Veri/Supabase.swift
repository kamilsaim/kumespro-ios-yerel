import Foundation
import Supabase

enum Sabitler {
    /// web `app.html` / `index.html` ile aynı proje ve anahtar (güvenlik RLS'te).
    static let supabaseURL = URL(string: "https://pddkeomtxgygftuuwdzi.supabase.co")!
    static let supabaseAnahtar = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkZGtlb210eGd5Z2Z0dXV3ZHppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxNDA2MDUsImV4cCI6MjA5MjcxNjYwNX0.K1EA-uc0rPpAFQvFVTBFeXOUsE6ZA3ZB6HhT-_wCZhM"
    /// Google girişi dönüşü (Supabase Redirect URLs'te kayıtlı, Android ile aynı)
    static let girisDonusu = URL(string: "com.kamilsaim.kumespro://auth-callback")!
    static let appGroup = "group.com.kamilsaim.kumespro"
    static let gizlilik = URL(string: "https://kayserisustavuklari.github.io/kumespro/gizlilik-politikasi.html")!
    static let destek = "saimkamil@gmail.com"
    static let yedekHatirlatmaGun = 30
}

/// Tek Supabase istemcisi. Düz JSON çözücü: satırlar `[String: JSON]` olarak okunur.
let supabase = SupabaseClient(
    supabaseURL: Sabitler.supabaseURL,
    supabaseKey: Sabitler.supabaseAnahtar,
    options: SupabaseClientOptions(
        db: .init(decoder: JSONDecoder()),
        auth: .init(redirectToURL: Sabitler.girisDonusu,
                    emitLocalSessionAsInitialSession: true)
    )
)
