import Foundation

/// Serbest JSON değeri. JSONB sütunlarındaki (irklar, hareketler, urunler, kaynaklar, cikim) nesneler
/// web'in bilmediğimiz alanlar da ekleyebileceği biçimde saklanır; Swift tarafı yalnız tanıdığı alanları
/// değiştirir, gerisi olduğu gibi geri yazılır (veri kaybı olmasın).
public enum JSON: Codable, Equatable, Hashable, Sendable {
    case null
    case bool(Bool)
    case sayi(Double)
    case metin(String)
    case dizi([JSON])
    case nesne([String: JSON])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let d = try? c.decode(Double.self) { self = .sayi(d); return }
        if let s = try? c.decode(String.self) { self = .metin(s); return }
        if let a = try? c.decode([JSON].self) { self = .dizi(a); return }
        if let o = try? c.decode([String: JSON].self) { self = .nesne(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Tanınmayan JSON değeri")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .sayi(let d):
            // Tam sayılar "3" olarak yazılsın (web `3.0` ile karşılaştırmada sorun çıkarmaz ama temiz kalsın)
            if d.rounded() == d, abs(d) < 9_007_199_254_740_992 { try c.encode(Int64(d)) } else { try c.encode(d) }
        case .metin(let s): try c.encode(s)
        case .dizi(let a): try c.encode(a)
        case .nesne(let o): try c.encode(o)
        }
    }

    // MARK: Okuma yardımcıları (web'deki `x || 0`, `x || ''` gevşekliğiyle)

    public var double: Double? {
        switch self {
        case .sayi(let d): return d
        case .metin(let s): return Double(s.replacingOccurrences(of: ",", with: "."))
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    public var int: Int? {
        guard let d = double, d.isFinite else { return nil }
        return Int(exactly: d.rounded(.towardZero))
    }

    public var string: String? {
        switch self {
        case .metin(let s): return s
        case .sayi(let d):
            if let tam = Int64(exactly: d) { return String(tam) }
            return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    public var bool: Bool? {
        switch self {
        case .bool(let b): return b
        case .sayi(let d): return d != 0
        default: return nil
        }
    }

    public var dizi: [JSON]? { if case .dizi(let a) = self { return a } else { return nil } }
    public var nesne: [String: JSON]? { if case .nesne(let o) = self { return o } else { return nil } }
    public var bosMu: Bool { if case .null = self { return true } else { return false } }

    public subscript(_ anahtar: String) -> JSON? { nesne?[anahtar] }

    public static func m(_ s: String?) -> JSON { s.map { .metin($0) } ?? .null }
    public static func s(_ i: Int) -> JSON { .sayi(Double(i)) }
    public static func s(_ d: Double) -> JSON { .sayi(d) }
}

public typealias JSONNesne = [String: JSON]

extension Dictionary where Key == String, Value == JSON {
    public func sayi(_ k: String) -> Int { self[k]?.int ?? 0 }
    public func ondalik(_ k: String) -> Double { self[k]?.double ?? 0 }
    public func metin(_ k: String) -> String? {
        guard let v = self[k], let s = v.string else { return nil }
        return s
    }
    /// Boş metni de yok sayar (web `x || null`).
    public func doluMetin(_ k: String) -> String? {
        guard let s = metin(k), !s.isEmpty else { return nil }
        return s
    }
    public mutating func yaz(_ k: String, _ v: String?) { self[k] = .m(v) }
    public mutating func yaz(_ k: String, _ v: Int) { self[k] = .s(v) }
    public mutating func yaz(_ k: String, _ v: Double) { self[k] = .s(v) }
}

/// Web `uid()`: 'x' + 7 rastgele karakter. Irk, kaynak ve parti kimlikleri bu biçimde.
public func yeniKimlik() -> String {
    let harfler = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    return "x" + String((0..<7).map { _ in harfler.randomElement()! })
}

/// Web'deki `p_…` parti kimliği (eski kayıt göçü).
func yeniPartiKimligi() -> String {
    let harfler = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    return "p_" + String((0..<9).map { _ in harfler.randomElement()! })
}
