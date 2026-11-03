import Foundation

/// "YYYY-MM-DD" biçimli günlerle çalışma. Tüm hesaplar yerel takvim günü üzerinden yapılır
/// (web'deki `T00:00:00` yerel gece yarısı yorumu).
public enum Gun {
    public static var takvim: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }()

    private static func bicimci(_ tz: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// Metni o günün yerel gece yarısına çevirir. ISO zaman damgasının yalnız tarih kısmı da kabul edilir.
    public static func coz(_ s: String?) -> Date? {
        guard let s, s.count >= 10 else { return nil }
        return bicimci(takvim.timeZone).date(from: String(s.prefix(10)))
    }

    public static func metin(_ d: Date) -> String { bicimci(takvim.timeZone).string(from: d) }

    public static var bugun: String { metin(Date()) }

    /// İki gün arasındaki takvim günü farkı (b − a).
    public static func fark(_ a: Date, _ b: Date) -> Int {
        let x = takvim.startOfDay(for: a), y = takvim.startOfDay(for: b)
        return takvim.dateComponents([.day], from: x, to: y).day ?? 0
    }

    public static func ekle(_ d: Date, gun: Int) -> Date {
        takvim.date(byAdding: .day, value: gun, to: d) ?? d
    }

    /// "12.03.2026" (web `fd`).
    public static func goster(_ s: String?) -> String {
        guard let d = coz(s) else { return "-" }
        return goster(d)
    }

    public static func goster(_ d: Date) -> String {
        let c = takvim.dateComponents([.day, .month, .year], from: d)
        return String(format: "%02d.%02d.%04d", c.day ?? 0, c.month ?? 0, c.year ?? 0)
    }

    static let aylar = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    static let kisaAylar = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
    static let gunler = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]

    /// "8 Kas"
    public static func kisa(_ d: Date) -> String {
        let c = takvim.dateComponents([.day, .month], from: d)
        return "\(c.day ?? 0) \(kisaAylar[(c.month ?? 1) - 1])"
    }

    public static func kisa(_ s: String?) -> String { coz(s).map(kisa) ?? "-" }

    /// "3 Kasım Pazartesi"
    public static func uzun(_ d: Date) -> String {
        let c = takvim.dateComponents([.day, .month, .weekday], from: d)
        return "\(c.day ?? 0) \(aylar[(c.month ?? 1) - 1]) \(gunler[(c.weekday ?? 1) - 1])"
    }

    /// "2026-11" → "Kasım 2026"
    public static func ayAdi(_ anahtar: String) -> String {
        let p = anahtar.split(separator: "-")
        guard p.count == 2, let y = Int(p[0]), let a = Int(p[1]), (1...12).contains(a) else { return anahtar }
        return "\(aylar[a - 1]) \(y)"
    }
}

/// Civciv yaşı (web `gunStr`): "bugün", "12 günlük", "2 aylık", "1ay 5g".
public func gunlukMetni(_ g: Int?) -> String {
    guard let g else { return "" }
    if g == 0 { return "bugün" }
    if g < 30 { return "\(g) günlük" }
    let ay = g / 30, kg = g % 30
    return kg > 0 ? "\(ay)ay \(kg)g" : "\(ay) aylık"
}

/// Hayvan yaşı (web `yasHesapla`): "12g", "5ay", "1y 3ay".
public func yasMetni(_ dogum: String?, bugun: Date = Date()) -> String? {
    guard let d = Gun.coz(dogum) else { return nil }
    let gun = Gun.fark(d, bugun)
    if gun < 0 { return nil }
    if gun < 30 { return "\(gun)g" }
    let ay = gun / 30
    if ay < 12 { return "\(ay)ay" }
    let y = ay / 12, ka = ay % 12
    return ka > 0 ? "\(y)y \(ka)ay" : "\(y)y"
}

/// Partinin yaşı (gün), tarih yoksa nil.
public func partiYasi(_ tarih: String?, bugun: Date = Date()) -> Int? {
    guard let d = Gun.coz(tarih) else { return nil }
    return max(0, Gun.fark(d, bugun))
}
