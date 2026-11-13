import SwiftUI
import KumesCekirdek

// Renkler web `app.html` :root token'larından (--pri mavi, --ora turuncu, gri tonları).
// Açık / koyu görünüm UIColor trait'iyle seçilir. Ekranlarda ham hex kullanılmaz.

private func hex(_ v: UInt32, _ a: CGFloat = 1) -> UIColor {
    UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

private func cift(_ acik: UIColor, _ koyu: UIColor) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? koyu : acik })
}

enum Renk {
    static let baslikYesil = Color(hex(0x003D2E))
    static let altin = Color(hex(0xF4D48B))
    static let zemin = cift(hex(0xF7F4EC), hex(0x101B17))
    static let kart = cift(hex(0xFFFCF5), hex(0x192820))
    static let kartIkinci = cift(hex(0xEEF1F4), hex(0x222C37))
    static let cizgi = cift(hex(0xE4E8EC), hex(0x2B3642))
    static let metin = cift(hex(0x1E2832), hex(0xEEF2F6))
    static let ikincil = cift(hex(0x5E6977), hex(0xA3AFBC))

    /// --pri: ana mavi (beyaz yazı alacak koyu ton)
    static let mavi = cift(hex(0x116242), hex(0x86D7AE))
    static let maviKoyu = cift(hex(0x003D2E), hex(0x003D2E))
    static let maviAcik = cift(hex(0xE5F1E7), hex(0x25382E))
    static let maviOrta = Color(hex(0x2E7FCC))

    /// --ora: turuncu
    static let turuncu = Color(hex(0xD2650F))
    static let turuncuParlak = Color(hex(0xE8711A))
    static let turuncuYazi = cift(hex(0xA9490C), hex(0xF6A35E))
    static let turuncuAcik = cift(hex(0xFEF0E6), hex(0x3A2717))
    static let turuncuIz = cift(hex(0xFAD9BF), hex(0x5A3A20))

    static let yesil = cift(hex(0x226B43), hex(0x5BC98A))
    static let yesilDolgu = Color(hex(0x2D8A55))
    static let yesilAcik = cift(hex(0xE5F5ED), hex(0x16342A))
    static let kirmizi = cift(hex(0xB03A2E), hex(0xF08378))
    static let kirmiziDolgu = Color(hex(0xC0392B))
    static let kirmiziAcik = cift(hex(0xFDECEA), hex(0x3D1F1C))
    static let kahve = cift(hex(0x7A4A22), hex(0xD7A57A))
    static let kahveAcik = cift(hex(0xF3EBE3), hex(0x33261B))
    static let camgobegi = cift(hex(0x1F6E62), hex(0x6FD0C0))
    static let camgobegiAcik = cift(hex(0xE3F4F1), hex(0x17322E))
}

extension Font {
    /// Dela Gothic One — logo ve büyük başlıklar.
    static func logo(_ boyut: CGFloat, relativeTo stil: Font.TextStyle = .largeTitle) -> Font {
        .custom("DelaGothicOne-Regular", size: boyut, relativeTo: stil)
    }
}

/// Tür başına renk + simge (kümes kartları, rozetler).
extension HayvanTuru {
    var renk: Color {
        switch self {
        case .tavuk, .karisik: return Renk.turuncuYazi
        case .guvercin: return Renk.mavi
        case .hindi, .tavus: return Renk.kahve
        case .kaz, .keklik: return Renk.camgobegi
        case .bildircin, .diger: return Renk.yesil
        }
    }

    var zemin: Color {
        switch self {
        case .tavuk, .karisik: return Renk.turuncuAcik
        case .guvercin: return Renk.maviAcik
        case .hindi, .tavus: return Renk.kahveAcik
        case .kaz, .keklik: return Renk.camgobegiAcik
        case .bildircin, .diger: return Renk.yesilAcik
        }
    }

    /// Tür resmi (Assets: Tur-<ad>); "diğer" için yok → SF Symbol.
    var resim: String? {
        switch self {
        case .tavuk, .karisik: return "Tur-tavuk"
        case .guvercin: return "Tur-guvercin"
        case .hindi: return "Tur-hindi"
        case .kaz: return "Tur-kaz"
        case .bildircin: return "Tur-bildircin"
        case .keklik: return "Tur-keklik"
        case .tavus: return "Tur-tavus"
        case .diger: return nil
        }
    }

    var simge: String {
        switch self {
        case .guvercin: return "bird.fill"
        case .tavuk, .hindi, .karisik, .bildircin, .keklik, .tavus: return "bird"
        case .kaz: return "drop.fill"
        case .diger: return "pawprint.fill"
        }
    }
}

extension GiderTuru {
    var simge: String {
        switch self {
        case .yem: return "leaf.fill"
        case .ilac: return "cross.vial.fill"
        case .hayvan: return "bird.fill"
        case .ekipman: return "wrench.and.screwdriver.fill"
        case .kulucka: return "oval.portrait.fill"
        case .bakim: return "sparkles"
        case .enerji: return "bolt.fill"
        case .kumes: return "house.fill"
        case .diger: return "shippingbox.fill"
        }
    }
}
