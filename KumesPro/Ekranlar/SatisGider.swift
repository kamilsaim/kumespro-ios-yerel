import SwiftUI
import KumesCekirdek

// MARK: - Satış formu

struct SatisFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let satisId: String?

    @State private var musteri = ""
    @State private var tarih = Gun.bugun
    @State private var urunler: [SatisUrunu] = []
    @State private var tamamiOdendi = true
    @State private var odenen: Double = 0
    @State private var not = ""
    @State private var calisiyor = false
    @State private var hazir = false
    @State private var silOnay = false
    @State private var rehberAcik = false

    private var toplam: Double {
        urunler.reduce(0) { r, x in r + Double(x.tip == .hayvan ? x.erkekAdet + x.disiAdet : x.adet) * x.fiyat }
    }

    var body: some View {
        let v = depo.veri
        NavigationStack {
            Form {
                Section {
                    TextField("Müşteri (isteğe bağlı)", text: $musteri)
                        .textContentType(.name)
                    Button { rehberAcik = true } label: { Label("Rehberden seç", systemImage: "person.crop.circle") }
                    GunSecici(baslik: "Tarih", gun: $tarih)
                }
                ForEach(urunler) { u in
                    Section {
                        UrunSatiri(urun: urunBag(u.id), veri: v, eski: eskiSatis)
                    } header: {
                        HStack {
                            Text("Ürün")
                            Spacer()
                            Button("Kaldır", role: .destructive) { urunler.removeAll { $0.id == u.id } }
                                .font(.caption.weight(.semibold)).textCase(nil)
                        }
                    }
                }
                Section {
                    Button { urunler.append(yeniUrun(v)) } label: { Label("Ürün ekle", systemImage: "plus.circle.fill") }
                }
                Section("Ödeme") {
                    HStack {
                        Text("Toplam")
                        Spacer()
                        Text(para(toplam, kurusZorunlu: false)).font(.body.weight(.bold).monospacedDigit())
                    }
                    Toggle("Tamamı ödendi", isOn: $tamamiOdendi)
                    if !tamamiOdendi {
                        ParaAlani(baslik: "Ödenen", deger: $odenen)
                        HStack {
                            Text("Kalan (alacak)")
                            Spacer()
                            Text(para(max(0, toplam - odenen))).font(.body.weight(.bold).monospacedDigit()).foregroundStyle(Renk.turuncuYazi)
                        }
                    }
                }
                Section("Not") { TextField("İsteğe bağlı", text: $not, axis: .vertical) }
                if satisId != nil {
                    Section { Button("Satışı sil", role: .destructive) { silOnay = true } }
                }
            }
            .kpZemin()
            .navigationTitle(satisId == nil ? "Yeni satış" : "Satış düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Kaydet", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
            .onAppear(perform: doldur)
            .confirmationDialog("Bu satış silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Satışı sil", role: .destructive) {
                    guard let id = satisId else { return }
                    Task {
                        do { try await depo.satisSil(id); kapat(); gezinti.bildir("Satış silindi, stoklar geri yüklendi") }
                        catch { gezinti.goster(error) }
                    }
                }
            } message: { Text("Satılan hayvan/civcivler ilgili kümes/üniteye geri eklenir.") }
        }
        .interactiveDismissDisabled(calisiyor)
        .background {
            RehberSecici(acik: $rehberAcik, sec: { ad in
                if ad.isEmpty { gezinti.goster(KuralHatasi("Seçilen kişinin adı bulunamadı.")) }
                else { musteri = ad }
            }).frame(width: 0, height: 0)
        }
    }

    private var eskiSatis: Satis? { satisId.flatMap { id in depo.veri.satislar.first { $0.id == id } } }

    private func yeniUrun(_ v: Veri) -> SatisUrunu {
        let k = v.kumesler.first?.id
        return .yeni(tip: v.kumesler.isEmpty ? .yumurta : .hayvan, kumesId: k, irkId: v.varsayilanIrk(k), uniteId: v.uniteler.first?.id)
    }

    private func urunBag(_ id: UUID) -> Binding<SatisUrunu> {
        Binding(get: { urunler.first { $0.id == id } ?? SatisUrunu(ham: [:]) },
                set: { y in if let i = urunler.firstIndex(where: { $0.id == id }) { urunler[i].ham = y.ham } })
    }

    private func doldur() {
        guard !hazir else { return }
        hazir = true
        if let s = eskiSatis {
            musteri = s.musteri ?? ""; tarih = s.tarih; urunler = s.urunler; not = s.not ?? ""
            tamamiOdendi = s.kalan <= 0
            odenen = s.odenen
        } else {
            urunler = [yeniUrun(depo.veri)]
        }
    }

    private func kaydet() async {
        do {
            try await depo.satisKaydet(eskiId: satisId, musteri: musteri, tarih: tarih, urunler: urunler,
                                       odenen: tamamiOdendi ? nil : odenen, not: not)
            kapat()
            gezinti.bildir("Satış \(satisId == nil ? "kaydedildi" : "güncellendi") · \(para(toplam))")
        } catch { gezinti.goster(error) }
    }
}

/// Bir satış satırı: tip + kaynak + adet + fiyat.
struct UrunSatiri: View {
    @Binding var urun: SatisUrunu
    let veri: Veri
    let eski: Satis?

    var body: some View {
        Picker("Tür", selection: Binding(get: { urun.tip }, set: { tipDegisti($0) })) {
            ForEach(UrunTipi.allCases) { t in Text(t.ad).tag(t) }
        }
        switch urun.tip {
        case .hayvan: hayvan
        case .civciv: civciv
        default:
            TextField(urun.tip == .yumurta ? "Ürün adı (isteğe bağlı)" : "Ürün adı", text: $urun.ad)
            SayiSatiri(baslik: "Adet", deger: $urun.adet)
        }
        ParaAlani(baslik: "Birim fiyat", deger: $urun.fiyat)
        let adet = urun.tip == .hayvan ? urun.erkekAdet + urun.disiAdet : urun.adet
        if adet > 0, urun.fiyat > 0 {
            HStack {
                Spacer()
                Text("\(adet) × \(para(urun.fiyat)) = ").foregroundStyle(Renk.ikincil)
                    + Text(para(Double(adet) * urun.fiyat)).foregroundStyle(Renk.yesil).bold()
            }
            .font(.footnote)
        }
    }

    @ViewBuilder private var hayvan: some View {
        let k = veri.kumes(urun.kumesId)
        let ir = k?.irklar.first { $0.id == urun.irkId }
        // Düzenlemede eski satıştaki adetler stoğa geri sayılır (kredi)
        let kr = eski?.urunler.filter { $0.tip == .hayvan && $0.kumesId == urun.kumesId && $0.irkId == urun.irkId }
            .reduce((0, 0)) { ($0.0 + $1.erkekAdet, $0.1 + $1.disiAdet) } ?? (0, 0)
        Picker("Kümes", selection: Binding(get: { urun.kumesId ?? "" }, set: { y in
            urun.kumesId = y; urun.irkId = veri.varsayilanIrk(y); urun.erkekAdet = 0; urun.disiAdet = 0
        })) {
            ForEach(veri.kumesler) { k in Text(k.ad).tag(k.id) }
        }
        Picker("Irk", selection: Binding(get: { urun.irkId ?? "" }, set: { y in
            urun.irkId = y.isEmpty ? nil : y; urun.erkekAdet = 0; urun.disiAdet = 0
        })) {
            Text("Seçin").tag("")
            ForEach(k?.irklar ?? []) { r in Text("\(r.ad) (E \(r.erkek) · D \(r.disi))").tag(r.id) }
        }
        if let ir {
            SayiSatiri(baslik: "Erkek", not: "stok \(ir.erkek + kr.0)", deger: $urun.erkekAdet, ust: ir.erkek + kr.0)
            SayiSatiri(baslik: "Dişi", not: "stok \(ir.disi + kr.1)", deger: $urun.disiAdet, ust: ir.disi + kr.1)
        } else {
            Text("Satış için bir ırk seçin").font(.footnote).foregroundStyle(Renk.turuncuYazi)
        }
    }

    @ViewBuilder private var civciv: some View {
        let u = veri.unite(urun.uniteId)
        let p = urun.partiId.flatMap { u?.parti($0) }
        let kr = eski?.urunler.filter { $0.tip == .civciv && $0.partiId == urun.partiId && urun.partiId != nil }
            .reduce(0) { $0 + $1.adet } ?? 0
        Picker("Ünite", selection: Binding(get: { urun.uniteId ?? "" }, set: { y in
            urun.uniteId = y; urun.partiId = nil; urun.adet = 0
        })) {
            ForEach(veri.uniteler) { u in Text("\(u.ad) (\(u.adet))").tag(u.id) }
        }
        Picker("Parti", selection: Binding(get: { urun.partiId ?? "" }, set: { y in urun.partiId = y.isEmpty ? nil : y; urun.adet = 0 })) {
            Text("Seçin").tag("")
            ForEach(partiSecenekleri(u), id: \.partiId) { p in
                Text("\(p.kaynak) · \(p.kalan) adet" + (partiYasi(p.tarih).map { " · " + gunlukMetni($0) } ?? "")).tag(p.partiId ?? "")
            }
        }
        if let p {
            SayiSatiri(baslik: "Adet", not: "kalan \(p.kalan + kr)", deger: $urun.adet, ust: p.kalan + kr)
        } else {
            Text("Satış için bir parti seçin").font(.footnote).foregroundStyle(Renk.turuncuYazi)
        }
    }

    /// Stoğu olan partiler + düzenlenen satışın kendi partisi (stoğu bitmiş olsa da).
    private func partiSecenekleri(_ u: Unite?) -> [UniteHareketi] {
        guard let u else { return [] }
        var l = u.aktifPartiler
        if let pid = urun.partiId, !l.contains(where: { $0.partiId == pid }), let p = u.parti(pid) { l.append(p) }
        return l
    }

    private func tipDegisti(_ t: UrunTipi) {
        let k = veri.kumesler.first?.id
        urun.tip = t
        urun.kumesId = k; urun.irkId = veri.varsayilanIrk(k)
        urun.uniteId = veri.uniteler.first?.id; urun.partiId = nil
        urun.erkekAdet = 0; urun.disiAdet = 0; urun.adet = 0
    }
}

// MARK: - Gider formu

struct GiderFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let giderId: String?

    @State private var tur: GiderTuru = .yem
    @State private var aciklama = ""
    @State private var tutar: Double = 0
    @State private var tarih = Gun.bugun
    @State private var kumesId = ""
    @State private var tamamiOdendi = true
    @State private var odenen: Double = 0
    @State private var calisiyor = false
    @State private var hazir = false
    @State private var silOnay = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tür", selection: $tur) {
                        ForEach(GiderTuru.allCases) { t in Label(t.ad, systemImage: t.simge).tag(t) }
                    }
                    TextField("Açıklama (örn. 10 çuval yem)", text: $aciklama)
                    ParaAlani(baslik: "Tutar", deger: $tutar)
                    GunSecici(baslik: "Tarih", gun: $tarih)
                    Picker("Kümes", selection: $kumesId) {
                        Text("Genel").tag("")
                        ForEach(depo.veri.kumesler) { k in Text(k.ad).tag(k.id) }
                    }
                }
                Section("Ödeme") {
                    Toggle("Tamamı ödendi", isOn: $tamamiOdendi)
                    if !tamamiOdendi {
                        ParaAlani(baslik: "Ödenen", deger: $odenen)
                        HStack {
                            Text("Kalan (borç)")
                            Spacer()
                            Text(para(max(0, tutar - odenen))).font(.body.weight(.bold).monospacedDigit()).foregroundStyle(Renk.kirmizi)
                        }
                    }
                }
                if giderId != nil {
                    Section { Button("Gideri sil", role: .destructive) { silOnay = true } }
                }
            }
            .kpZemin()
            .navigationTitle(giderId == nil ? "Gider ekle" : "Gider düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Kaydet", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
            .onAppear {
                guard !hazir else { return }
                hazir = true
                if let g = depo.veri.giderler.first(where: { $0.id == giderId }) {
                    tur = g.turu; aciklama = g.aciklama ?? ""; tutar = g.tutar; tarih = g.tarih; kumesId = g.kumesId ?? ""
                    tamamiOdendi = g.kalan <= 0; odenen = g.odenen
                }
            }
            .confirmationDialog("Bu gider silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Gideri sil", role: .destructive) {
                    guard let id = giderId else { return }
                    Task { do { try await depo.giderSil(id); kapat(); gezinti.bildir("Gider silindi") } catch { gezinti.goster(error) } }
                }
            }
        }
        .interactiveDismissDisabled(calisiyor)
    }

    private func kaydet() async {
        let a = aciklama.trimmingCharacters(in: .whitespaces)
        let g = Gider(id: giderId ?? "", tur: tur.rawValue, aciklama: a.isEmpty ? nil : a, tutar: tutar, tarih: tarih,
                      kumesId: kumesId.isEmpty ? nil : kumesId, odenen: tamamiOdendi ? tutar : odenen)
        do {
            try await depo.giderKaydet(g)
            kapat(); gezinti.bildir("Gider kaydedildi · \(para(tutar))")
        } catch { gezinti.goster(error) }
    }
}
