import SwiftUI
import KumesCekirdek

/// Beyaz, yuvarlak köşeli kart (20 pt, yumuşak gölge).
struct Kart<Icerik: View>: View {
    var dolgu: CGFloat = 16
    var zemin: Color = Renk.kart
    var golge = true
    @ViewBuilder var icerik: () -> Icerik

    var body: some View {
        icerik()
            .padding(dolgu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(zemin, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: golge ? Color.black.opacity(0.06) : .clear, radius: 10, y: 4)
    }
}

/// Renkli kare ikon rozeti.
struct IkonRozeti: View {
    let simge: String
    let renk: Color
    let zemin: Color
    var boyut: CGFloat = 36

    var body: some View {
        Image(systemName: simge)
            .font(.system(size: boyut * 0.48, weight: .semibold))
            .foregroundStyle(renk)
            .frame(width: boyut, height: boyut)
            .background(zemin, in: RoundedRectangle(cornerRadius: boyut * 0.34, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Kümes türü rozeti: tür resmi varsa resim, yoksa renkli sembol.
struct TurRozeti: View {
    let tur: HayvanTuru
    var boyut: CGFloat = 48

    var body: some View {
        if let r = tur.resim {
            Image(r)
                .resizable()
                .scaledToFill()
                .frame(width: boyut, height: boyut)
                .clipShape(RoundedRectangle(cornerRadius: boyut * 0.28, style: .continuous))
                .accessibilityHidden(true)
        } else {
            IkonRozeti(simge: tur.simge, renk: tur.renk, zemin: tur.zemin, boyut: boyut)
        }
    }
}

/// Küçük hap etiket.
struct Hap: View {
    let yazi: String
    var renk: Color = Renk.turuncuYazi
    var zemin: Color = Renk.turuncuAcik

    var body: some View {
        Text(yazi)
            .font(.caption.weight(.bold))
            .foregroundStyle(renk)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(zemin, in: Capsule())
            .lineLimit(1)
    }
}

/// Bölüm başlığı + isteğe bağlı sağ bağlantı.
struct BolumBasligi: View {
    let baslik: String
    var sag: String?
    var eylem: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(baslik).font(.title3.weight(.bold)).foregroundStyle(Renk.metin)
            Spacer()
            if let sag, let eylem {
                Button(sag, action: eylem).font(.subheadline.weight(.semibold))
            }
        }
        .padding(.top, 6)
    }
}

/// Halka ilerleme (kuluçka).
struct Halka: View {
    let oran: Double
    var renk: Color = Renk.turuncuParlak
    var iz: Color = Renk.turuncuIz
    var kalinlik: CGFloat = 7

    var body: some View {
        ZStack {
            Circle().stroke(iz, lineWidth: kalinlik)
            Circle().trim(from: 0, to: max(0, min(1, oran)))
                .stroke(renk, style: StrokeStyle(lineWidth: kalinlik, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Erkek/dişi oran çubuğu.
struct OranCubugu: View {
    let erkek: Int
    let disi: Int

    var body: some View {
        GeometryReader { g in
            let t = max(1, erkek + disi)
            HStack(spacing: 2) {
                if erkek > 0 { Capsule().fill(Renk.mavi).frame(width: g.size.width * CGFloat(erkek) / CGFloat(t)) }
                if disi > 0 { Capsule().fill(Renk.turuncuParlak) }
                if erkek + disi == 0 { Capsule().fill(Renk.cizgi) }
            }
        }
        .frame(height: 8)
        .accessibilityLabel("\(erkek) erkek, \(disi) dişi")
    }
}

/// Boş durum.
struct BosDurum: View {
    let simge: String
    let baslik: String
    var metin: String?
    var dugme: String?
    var eylem: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: simge).font(.system(size: 40, weight: .semibold)).foregroundStyle(Renk.mavi.opacity(0.7))
            Text(baslik).font(.headline).foregroundStyle(Renk.metin)
            if let metin { Text(metin).font(.subheadline).foregroundStyle(Renk.ikincil).multilineTextAlignment(.center) }
            if let dugme, let eylem {
                Button(dugme, action: eylem).buttonStyle(.borderedProminent).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

/// Sayı adımlayıcı satırı (form içinde): "Erkek · stok 12   [−] 2 [+]"
struct SayiSatiri: View {
    let baslik: String
    var not: String?
    @Binding var deger: Int
    var ust: Int = 1_000_000
    var devreDisi = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(baslik)
                if let not { Text(not).font(.caption).foregroundStyle(Renk.ikincil) }
            }
            Spacer()
            HStack(spacing: 0) {
                Button { deger = max(0, deger - 1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .accessibilityLabel("\(baslik) azalt")
                TextField("0", value: $deger, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
                    .font(.body.weight(.bold).monospacedDigit())
                Button { deger = min(ust, deger + 1) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .accessibilityLabel("\(baslik) artır")
            }
            .buttonStyle(.borderless)
            .background(Renk.kartIkinci, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(devreDisi)
            .opacity(devreDisi ? 0.4 : 1)
        }
        .onChange(of: deger) { _, y in if y > ust { deger = ust } else if y < 0 { deger = 0 } }
    }
}

/// Para girişi (₺) — metin olarak tutulur, "1.250,50" gibi yazılabilir.
struct ParaAlani: View {
    let baslik: String
    @Binding var deger: Double
    @State private var metin = ""
    @FocusState private var odak: Bool

    var body: some View {
        HStack {
            Text(baslik)
            Spacer()
            TextField("₺0", text: $metin)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($odak)
                .frame(maxWidth: 150)
                .font(.body.weight(.semibold).monospacedDigit())
        }
        .onAppear { metin = ondalikMetni(deger) }
        .onChange(of: metin) { _, y in deger = ondalikCoz(y) ?? 0 }
        .onChange(of: deger) { _, y in
            if !odak, ondalikCoz(metin) ?? 0 != y { metin = ondalikMetni(y) }
        }
    }
}

/// Tarih seçici ("YYYY-MM-DD" metnine bağlı).
struct GunSecici: View {
    let baslik: String
    @Binding var gun: String

    var body: some View {
        DatePicker(baslik, selection: Binding(
            get: { Gun.coz(gun) ?? Date() },
            set: { gun = Gun.metin($0) }), displayedComponents: .date)
        .environment(\.locale, Locale(identifier: "tr_TR"))
    }
}

/// Kaydet düğmesi taşıyan form araç çubuğu: iki kez basmayı engeller (web `guardClick`).
struct FormAracCubugu: ToolbarContent {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @State private var ilkVeri: Veri?
    let baslik: String
    @Binding var calisiyor: Bool
    var kaydet: () async -> Void
    var vazgec: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Vazgeç", action: vazgec).disabled(calisiyor) }
        ToolbarItem(placement: .confirmationAction) {
            if calisiyor {
                ProgressView()
            } else {
                Button(baslik) {
                    guard let ilkVeri, ilkVeri == depo.veri else {
                        gezinti.goster(KuralHatasi("Form açıldıktan sonra veriler değişti. Formu yeniden açıp tekrar deneyin."))
                        return
                    }
                    calisiyor = true
                    Task { await kaydet(); calisiyor = false }
                }
                .fontWeight(.bold)
                .onAppear { if ilkVeri == nil { ilkVeri = depo.veri } }
            }
        }
    }
}

extension View {
    /// Liste/Form zemini.
    func kpZemin() -> some View {
        self.scrollContentBackground(.hidden).background(Renk.zemin)
    }
}
