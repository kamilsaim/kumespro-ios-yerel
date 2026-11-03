import SwiftUI
import KumesCekirdek

struct KumeslerEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti

    var body: some View {
        @Bindable var g = gezinti
        let v = depo.veri
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Bölüm", selection: $g.uniteBolumu) {
                    Text("Kümesler").tag(false)
                    Text("Civciv üniteleri · \(v.uniteler.count)").tag(true)
                }
                .pickerStyle(.segmented)

                if gezinti.uniteBolumu {
                    if v.uniteler.isEmpty {
                        BosDurum(simge: "shippingbox", baslik: "Civciv ünitesi yok",
                                 metin: "Kuluçkadan çıkan civcivleri ünitelerde partiler halinde takip edersin.",
                                 dugme: depo.saltOkunur ? nil : "Ünite ekle") { gezinti.ac(.yeniUnite) }
                    }
                    ForEach(v.uniteler) { u in
                        NavigationLink(value: u.id) { UniteKarti(u: u) }.buttonStyle(.plain)
                    }
                } else {
                    if v.kumesler.isEmpty {
                        BosDurum(simge: "house", baslik: "Henüz kümes yok", metin: "Kümeslerini ve ırklarını ekleyerek başla.",
                                 dugme: depo.saltOkunur ? nil : "Kümes ekle") { gezinti.ac(.kumes(nil)) }
                    }
                    ForEach(v.kumesler) { k in
                        NavigationLink(value: KumesRota(id: k.id)) { KumesKarti(k: k) }.buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 12)
        }
        .background(Renk.zemin)
        .refreshable { await depo.yukle() }
        .navigationTitle("Kümesler")
        .navigationDestination(for: KumesRota.self) { r in KumesDetay(kumesId: r.id) }
        .navigationDestination(for: String.self) { id in UniteDetay(uniteId: id) }
        .toolbar {
            if !depo.saltOkunur {
                ToolbarItem(placement: .primaryAction) {
                    Button { gezinti.ac(gezinti.uniteBolumu ? .yeniUnite : .kumes(nil)) } label: {
                        Image(systemName: "plus").fontWeight(.bold)
                    }
                    .accessibilityLabel(gezinti.uniteBolumu ? "Ünite ekle" : "Kümes ekle")
                }
            }
        }
    }
}

struct KumesRota: Hashable { let id: String }

struct KumesKarti: View {
    let k: Kumes

    var body: some View {
        let t = k.turu
        Kart {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    TurRozeti(tur: t, boyut: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.ad).font(.headline).foregroundStyle(Renk.metin).lineLimit(1)
                        HStack(spacing: 6) {
                            Text("\(t.ad) · \(k.irklar.count) ırk").font(.subheadline).foregroundStyle(Renk.ikincil)
                            if let y = k.sonYas() { Hap(yazi: y, renk: Renk.ikincil, zemin: Renk.kartIkinci) }
                        }
                    }
                    Spacer()
                    if k.toplam == 0 {
                        Hap(yazi: "Boş", renk: .white, zemin: Renk.kirmiziDolgu)
                    } else {
                        Text("\(k.toplam)").font(.title.weight(.bold).monospacedDigit()).foregroundStyle(t.renk)
                    }
                }
                if k.toplam > 0 {
                    OranCubugu(erkek: k.erkek, disi: k.disi)
                    HStack {
                        Label("\(k.erkek) erkek", systemImage: "circle.fill").labelStyle(NoktaEtiket(renk: Renk.mavi))
                        Spacer()
                        Label("\(k.disi) dişi", systemImage: "circle.fill").labelStyle(NoktaEtiket(renk: Renk.turuncuParlak))
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(Renk.metin.opacity(0.8))
                }
                if k.irklar.count > 1 || (k.irklar.count == 1 && k.irklar[0].ad != "Genel") {
                    AkisDuzeni(aralik: 6) {
                        ForEach(k.irklar) { r in
                            Hap(yazi: "\(r.ad.isEmpty ? "Genel" : r.ad) \(r.toplam)", renk: t.renk, zemin: t.zemin)
                        }
                    }
                }
            }
        }
        .overlay {
            if k.toplam == 0 {
                RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Renk.kirmiziDolgu.opacity(0.45), lineWidth: 2)
            }
        }
    }
}

struct NoktaEtiket: LabelStyle {
    let renk: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            Circle().fill(renk).frame(width: 8, height: 8)
            configuration.title
        }
    }
}

/// Satıra sığmayanı alta geçiren basit akış düzeni (etiketler).
struct AkisDuzeni: Layout {
    var aralik: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, satir: CGFloat = 0, enGenis: CGFloat = 0
        for s in subviews {
            let b = s.sizeThatFits(.unspecified)
            if x > 0, x + b.width > w { x = 0; y += satir + aralik; satir = 0 }
            x += b.width + aralik
            satir = max(satir, b.height)
            enGenis = max(enGenis, x - aralik)
        }
        return CGSize(width: min(w, enGenis), height: y + satir)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, satir: CGFloat = 0
        for s in subviews {
            let b = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + b.width > bounds.maxX { x = bounds.minX; y += satir + aralik; satir = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(b))
            x += b.width + aralik
            satir = max(satir, b.height)
        }
    }
}

// MARK: - Kümes detayı

struct KumesDetay: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let kumesId: String
    @State private var hareketlerAcik = false
    @State private var silOnay = false
    @State private var silinecekHareket: Int?

    var body: some View {
        if let k = depo.veri.kumes(kumesId) {
            let t = k.turu
            List {
                Section {
                    VStack(spacing: 10) {
                        TurRozeti(tur: t, boyut: 72)
                        Text("\(k.toplam)").font(.system(size: 44, weight: .bold).monospacedDigit())
                        Text("TOPLAM HAYVAN").font(.caption.weight(.bold)).foregroundStyle(Renk.ikincil).tracking(0.5)
                        HStack(spacing: 8) {
                            Hap(yazi: "Erkek \(k.erkek)", renk: Renk.mavi, zemin: Renk.maviAcik)
                            Hap(yazi: "Dişi \(k.disi)", renk: Renk.turuncuYazi, zemin: Renk.turuncuAcik)
                        }
                        if !depo.saltOkunur {
                            HStack(spacing: 10) {
                                Button { gezinti.ac(.hayvan(kumesId: k.id, islem: .ekle)) } label: {
                                    Label("Hayvan ekle", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 32)
                                }.buttonStyle(.borderedProminent)
                                Button { gezinti.ac(.hayvan(kumesId: k.id, islem: .cikar)) } label: {
                                    Label("Çıkar", systemImage: "minus").frame(maxWidth: .infinity, minHeight: 32)
                                }.buttonStyle(.bordered).tint(Renk.kirmizi)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                if !k.irklar.isEmpty {
                    Section("Irklar ve gruplar") {
                        ForEach(k.irklar) { r in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(r.ad.isEmpty ? "İsimsiz" : r.ad).font(.body.weight(.semibold))
                                    Spacer()
                                    Text("\(r.toplam) adet · %\(k.toplam > 0 ? Int((Double(r.toplam) / Double(k.toplam) * 100).rounded()) : 0)")
                                        .font(.subheadline.monospacedDigit()).foregroundStyle(Renk.ikincil)
                                }
                                OranCubugu(erkek: r.erkek, disi: r.disi)
                                Text("\(r.erkek) erkek · \(r.disi) dişi").font(.caption).foregroundStyle(Renk.ikincil)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if let n = k.not {
                    Section("Not") { Text(n) }
                }

                if !k.hareketler.isEmpty {
                    Section {
                        DisclosureGroup(isExpanded: $hareketlerAcik) {
                            ForEach(Array(k.hareketler.enumerated()).reversed().prefix(20), id: \.offset) { i, h in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: h.islem == .ekle ? "plus.circle.fill" : "minus.circle.fill")
                                        .foregroundStyle(h.islem == .ekle ? Renk.yesil : Renk.kirmizi)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(h.irkAd ?? "Genel") · \(h.erkek) E · \(h.disi) D").font(.subheadline.weight(.semibold))
                                        Text([Gun.goster(h.tarih), h.not, h.dogumTarihi.map { "doğum " + Gun.goster($0) }]
                                            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption).foregroundStyle(Renk.ikincil)
                                    }
                                }
                                .swipeActions {
                                    if !depo.saltOkunur {
                                        Button("Sil", role: .destructive) { silinecekHareket = i }
                                    }
                                }
                            }
                        } label: {
                            Text("Hareket geçmişi (\(k.hareketler.count))").font(.body.weight(.semibold))
                        }
                    } footer: {
                        if !depo.saltOkunur { Text("Bir hareketi silmek için sola kaydır; etkisi geri alınır.") }
                    }
                }

                if !depo.saltOkunur {
                    Section {
                        Button("Kümesi sil", role: .destructive) { silOnay = true }
                    }
                }
            }
            .kpZemin()
            .navigationTitle(k.ad)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !depo.saltOkunur {
                    ToolbarItem(placement: .primaryAction) { Button("Düzenle") { gezinti.ac(.kumes(k.id)) } }
                }
            }
            .confirmationDialog("\"\(k.ad)\" silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Kümesi sil", role: .destructive) {
                    Task {
                        do { try await depo.kumesSil(k.id); kapat(); gezinti.bildir("Kümes silindi") }
                        catch { gezinti.goster(error) }
                    }
                }
            } message: { Text("Kümes ve ırk bilgileri kalıcı olarak silinir.") }
            .confirmationDialog("Bu hareket silinsin mi?", isPresented: Binding(get: { silinecekHareket != nil }, set: { if !$0 { silinecekHareket = nil } }),
                                titleVisibility: .visible) {
                Button("Hareketi sil", role: .destructive) {
                    guard let i = silinecekHareket else { return }
                    Task {
                        do { try await depo.kumesHareketiSil(kumesId: k.id, indeks: i); gezinti.bildir("Hareket silindi") }
                        catch { gezinti.goster(error) }
                    }
                }
            } message: { Text("Hareketin hayvan sayılarına etkisi geri alınır.") }
        } else {
            BosDurum(simge: "house", baslik: "Kümes bulunamadı")
        }
    }
}

// MARK: - Kümes formu

struct KumesFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let kumesId: String?

    @State private var ad = ""
    @State private var tur: HayvanTuru = .tavuk
    @State private var not = ""
    @State private var irklar: [Irk] = []
    @State private var calisiyor = false
    @State private var hazir = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kümes adı", text: $ad)
                    Picker("Tür", selection: $tur) {
                        ForEach(HayvanTuru.allCases) { t in Text(t.ad).tag(t) }
                    }
                }
                Section {
                    // Kimliğe göre bağlama: ForEach($dizi) ile satır silmek çökebiliyor (Türbedar dersi)
                    ForEach(irklar) { r in
                        VStack(spacing: 8) {
                            TextField("Irk / grup adı", text: irkBag(r.id, \.ad)).font(.body.weight(.semibold))
                            SayiSatiri(baslik: "Erkek", deger: irkBag(r.id, \.erkek))
                            SayiSatiri(baslik: "Dişi", deger: irkBag(r.id, \.disi))
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { irklar.remove(atOffsets: $0) }
                    Button { irklar.append(Irk(ad: "")) } label: { Label("Irk ekle", systemImage: "plus.circle.fill") }
                } header: { Text("Irklar") } footer: {
                    Text("Satışta ve hayvan hareketlerinde ırk seçilir. Silmek için sola kaydır.")
                }
                Section("Not") {
                    TextField("İsteğe bağlı", text: $not, axis: .vertical).lineLimit(2...5)
                }
            }
            .kpZemin()
            .navigationTitle(kumesId == nil ? "Yeni kümes" : "Kümes düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Kaydet", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
            .onAppear(perform: doldur)
        }
    }

    private func irkBag<T>(_ id: String, _ yol: WritableKeyPath<Irk, T>) -> Binding<T> where T: DefaultDeger {
        Binding(
            get: { irklar.first { $0.id == id }?[keyPath: yol] ?? T.varsayilan },
            set: { y in if let i = irklar.firstIndex(where: { $0.id == id }) { irklar[i][keyPath: yol] = y } })
    }

    private func doldur() {
        guard !hazir else { return }
        hazir = true
        if let k = depo.veri.kumes(kumesId) {
            ad = k.ad; tur = k.turu; not = k.not ?? ""; irklar = k.irklar
        }
    }

    private func kaydet() async {
        let a = ad.trimmingCharacters(in: .whitespaces)
        guard !a.isEmpty else { gezinti.goster(KuralHatasi("Kümes adı gereklidir!")); return }
        var k = depo.veri.kumes(kumesId) ?? Kumes(ad: a, tur: tur.rawValue)
        k.ad = a; k.tur = tur.rawValue
        let n = not.trimmingCharacters(in: .whitespaces)
        k.not = n.isEmpty ? nil : n
        k.irklar = irklar.map { var r = $0; r.ad = r.ad.trimmingCharacters(in: .whitespaces); return r }
        do {
            try await depo.kumesKaydet(k)
            kapat()
            gezinti.bildir("Kümes kaydedildi")
        } catch { gezinti.goster(error) }
    }
}

/// Kimliğe göre bağlamada kayıt bulunamazsa dönecek değer.
protocol DefaultDeger { static var varsayilan: Self { get } }
extension String: DefaultDeger { static var varsayilan: String { "" } }
extension Int: DefaultDeger { static var varsayilan: Int { 0 } }
extension Double: DefaultDeger { static var varsayilan: Double { 0 } }

// MARK: - Hayvan ekle / çıkar

struct HayvanFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let kumesId: String
    @State var islem: Islem

    @State private var irkId: String = ""
    @State private var erkek = 0
    @State private var disi = 0
    @State private var not = ""
    @State private var dogum = Gun.bugun
    @State private var dogumVar = false
    @State private var calisiyor = false

    init(kumesId: String, islem: Islem) {
        self.kumesId = kumesId
        _islem = State(initialValue: islem)
    }

    var body: some View {
        let k = depo.veri.kumes(kumesId)
        let ir = k?.irklar.first { $0.id == irkId }
        let stokE = ir?.erkek ?? k?.erkek ?? 0
        let stokD = ir?.disi ?? k?.disi ?? 0
        NavigationStack {
            Form {
                Section {
                    Picker("İşlem", selection: $islem) {
                        Text("Ekle").tag(Islem.ekle)
                        Text("Çıkar").tag(Islem.cikar)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    Picker("Irk", selection: $irkId) {
                        Text("Genel (tüm kümes)").tag("")
                        ForEach(k?.irklar ?? []) { r in Text(r.ad.isEmpty ? "İsimsiz" : r.ad).tag(r.id) }
                    }
                    SayiSatiri(baslik: "Erkek", not: islem == .cikar ? "mevcut \(stokE)" : nil, deger: $erkek,
                               ust: islem == .cikar ? stokE : 1_000_000)
                    SayiSatiri(baslik: "Dişi", not: islem == .cikar ? "mevcut \(stokD)" : nil, deger: $disi,
                               ust: islem == .cikar ? stokD : 1_000_000)
                } header: { Text(k?.ad ?? "") }
                if islem == .ekle {
                    Section {
                        Toggle("Doğum tarihi gir", isOn: $dogumVar)
                        if dogumVar { GunSecici(baslik: "Doğum tarihi", gun: $dogum) }
                    } footer: { Text("Kümes kartında hayvanların yaşı gösterilir.") }
                }
                Section("Not") {
                    TextField(islem == .ekle ? "Alım, doğum, açıklama…" : "Ölüm sebebi, kayıp, hastalık…", text: $not, axis: .vertical)
                }
            }
            .kpZemin()
            .navigationTitle(islem == .ekle ? "Hayvan ekle" : "Hayvan çıkar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Kaydet", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
        }
        .presentationDetents([.large])
    }

    private func kaydet() async {
        do {
            try await depo.hayvanIslemi(kumesId: kumesId, islem: islem, irkId: irkId.isEmpty ? nil : irkId,
                                        erkek: erkek, disi: disi, not: not.trimmingCharacters(in: .whitespaces),
                                        dogum: islem == .ekle && dogumVar ? dogum : nil)
            kapat()
            gezinti.bildir(islem == .ekle ? "\(erkek + disi) hayvan eklendi" : "\(erkek + disi) hayvan çıkarıldı")
        } catch { gezinti.goster(error) }
    }
}
