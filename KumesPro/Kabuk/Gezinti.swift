import SwiftUI
import Observation
import KumesCekirdek

enum Sekme: Hashable, CaseIterable {
    case ozet, kumesler, kulucka, finans
}

/// Alttan açılan pencereler (tek `.sheet(item:)` kökten yönetir).
enum Pencere: Identifiable, Equatable {
    case ekleMenusu
    case satis(String?)
    case gider(String?)
    case kulucka(String?)
    case cikim(String)
    case kumes(String?)
    case hayvan(kumesId: String, islem: Islem)
    case yeniUnite
    case uniteDuzenle(String)
    case partiEkle(String)
    case partiCikar(uniteId: String, partiId: String)
    case partiDuzenle(uniteId: String, partiId: String)
    case aktar(uniteId: String, partiId: String)
    case alacaklar
    case borclar
    case ayarlar

    var id: String {
        switch self {
        case .ekleMenusu: return "ekle"
        case .satis(let i): return "satis-\(i ?? "")"
        case .gider(let i): return "gider-\(i ?? "")"
        case .kulucka(let i): return "kulucka-\(i ?? "")"
        case .cikim(let i): return "cikim-\(i)"
        case .kumes(let i): return "kumes-\(i ?? "")"
        case .hayvan(let k, let i): return "hayvan-\(k)-\(i.rawValue)"
        case .yeniUnite: return "yeniUnite"
        case .uniteDuzenle(let i): return "uniteDuzenle-\(i)"
        case .partiEkle(let u): return "partiEkle-\(u)"
        case .partiCikar(let u, let p): return "partiCikar-\(u)-\(p)"
        case .partiDuzenle(let u, let p): return "partiDuzenle-\(u)-\(p)"
        case .aktar(let u, let p): return "aktar-\(u)-\(p)"
        case .alacaklar: return "alacaklar"
        case .borclar: return "borclar"
        case .ayarlar: return "ayarlar"
        }
    }
}

/// Uygulama içi mesaj (web `uyari`) ve kısa bildirim şeridi (web `toast`).
struct Mesaj: Identifiable, Equatable {
    let id = UUID()
    let baslik: String
    var metin: String?
}

@Observable @MainActor
final class Gezinti {
    static let ortak = Gezinti()

    var sekme: Sekme = .ozet
    var pencere: Pencere?
    var mesaj: Mesaj?
    var serit: String?
    /// Kümesler sekmesinde açık bölüm (kümes / ünite).
    var uniteBolumu = false
    var kayitBolumu = 0
    /// Soğuk açılışta ikon menüsü / bildirim: oturum hazır olunca işlenir.
    var bekleyenPencere: Pencere?
    var bekleyenSekme: Sekme?

    func ac(_ p: Pencere) {
        if pencere != nil {
            pencere = nil
            Task { try? await Task.sleep(for: .milliseconds(450)); pencere = p }
        } else {
            pencere = p
        }
    }

    func goster(_ hata: Error) {
        Titresim.hata()
        let m = (hata as? KuralHatasi)?.mesaj ?? hata.localizedDescription
        let satirlar = m.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        mesaj = Mesaj(baslik: satirlar.first.map(String.init) ?? "Hata",
                      metin: satirlar.count > 1 ? String(satirlar[1]).trimmingCharacters(in: .whitespacesAndNewlines) : nil)
    }

    func bildir(_ yazi: String) {
        Titresim.basari()
        serit = yazi
        let simdiki = yazi
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if serit == simdiki { serit = nil }
        }
    }

    func kisayol(_ tip: String) {
        switch Kisayol(rawValue: tip) {
        case .satis: bekleyenPencere = .satis(nil)
        case .gider: bekleyenPencere = .gider(nil)
        case .kulucka: bekleyenPencere = .kulucka(nil)
        case nil: break
        }
    }
}
