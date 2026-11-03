import Foundation

/// Para: "₺1.234,50" (web `fm`), kuruş yoksa "₺1.234".
public func para(_ n: Double, kurusZorunlu: Bool = false) -> String {
    let negatif = n < 0
    let kurusToplam = Int64((abs(n) * 100).rounded())
    let tam = kurusToplam / 100, kurus = kurusToplam % 100
    var s = String(tam)
    var parcalar: [String] = []
    while s.count > 3 {
        parcalar.insert(String(s.suffix(3)), at: 0)
        s = String(s.dropLast(3))
    }
    parcalar.insert(s, at: 0)
    var sonuc = "₺" + parcalar.joined(separator: ".")
    if kurus > 0 || kurusZorunlu { sonuc += "," + String(format: "%02d", kurus) }
    return (negatif ? "−" : "") + sonuc
}

/// Kullanıcı girişi: "1.250,5" / "1250.5" / "1250" → 1250.5
public func ondalikCoz(_ s: String) -> Double? {
    var t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "₺", with: "")
    if t.isEmpty { return nil }
    if t.contains(",") {
        t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
    }
    return Double(t)
}

/// Kullanıcıya gösterilen sayı girişi metni: 12.5 → "12,5", 12 → "12".
public func ondalikMetni(_ d: Double) -> String {
    if d == 0 { return "" }
    if d.rounded() == d { return String(Int64(d)) }
    return String(d).replacingOccurrences(of: ".", with: ",")
}

/// Hesap kartı (web `hesapGorunum`): Apple "E-postamı Gizle" adresi yerine ad ya da "Apple Hesabı".
public struct HesapGorunum: Equatable, Sendable {
    public let ad: String
    public let alt: String
    public let harf: String

    public init(eposta: String?, adSoyad: String?, saglayici: String?) {
        let e = eposta ?? ""
        let gizli = e.lowercased().hasSuffix("@privaterelay.appleid.com")
        let apple = gizli || saglayici == "apple"
        let isim = (adSoyad ?? "").trimmingCharacters(in: .whitespaces)
        if gizli {
            ad = isim.isEmpty ? "Apple Hesabı" : isim
            alt = "Apple ile giriş · e-posta gizli"
            harf = String((isim.isEmpty ? "A" : isim).prefix(1)).uppercased()
        } else {
            ad = e.isEmpty ? isim : e
            alt = apple ? "Apple ile giriş" : "Google ile giriş"
            harf = String((e.isEmpty ? (isim.isEmpty ? "?" : isim) : e).prefix(1)).uppercased()
        }
    }
}

/// Ana sayfa selamı (saat dilimine göre).
public func selam(_ saat: Int) -> String {
    switch saat {
    case 5..<11: return "Günaydın"
    case 11..<17: return "İyi günler"
    case 17..<22: return "İyi akşamlar"
    default: return "İyi geceler"
    }
}
