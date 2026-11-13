import SwiftUI
import KumesCekirdek

enum FinansFiltre: String, CaseIterable { case tumu = "Tümü", satislar = "Satışlar", giderler = "Giderler" }

/// Liste satırı: satış ya da gider.
struct FinansKaydi: Identifiable {
    let id: String
    let tarih: String
    var satis: Satis?
    var gider: Gider?
}

struct FinansGunu: Identifiable {
    let id: String
    let kayitlar: [FinansKaydi]
}

struct FinansEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @State private var ay: String?
    @State private var filtre: FinansFiltre = .tumu
    @State private var arama = ""
    @State private var silinecek: FinansKaydi?
    @State private var tahsil: Satis?

    var body: some View {
        let v = depo.veri
        let o = v.finansOzeti(ay: ay)
        let gruplar = gunGruplari(v)
        List {
            Section {
                ozetKarti(o)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                HStack(spacing: 10) {
                    kutu("ALACAĞIM", para(o.alacak), "\(o.alacakKisi) kişi", Renk.turuncuYazi, Renk.turuncuAcik) { gezinti.ac(.alacaklar) }
                    kutu("BORCUM", para(o.borc), "\(o.borcKayit) kayıt", Renk.kirmizi, Renk.kirmiziAcik) { gezinti.ac(.borclar) }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 4, trailing: 0)).listRowBackground(Color.clear)
                Picker("Filtre", selection: $filtre) {
                    ForEach(FinansFiltre.allCases, id: \.self) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0)).listRowBackground(Color.clear)
            }
            .listSectionSeparator(.hidden)

            if gruplar.isEmpty {
                Section {
                    BosDurum(simge: "tray", baslik: arama.isEmpty ? "Kayıt yok" : "Sonuç bulunamadı",
                             metin: arama.isEmpty ? "Satış ve giderlerini + düğmesinden ekleyebilirsin." : nil)
                        .listRowBackground(Color.clear)
                }
            }
            ForEach(gruplar) { grup in
                Section(gunBasligi(grup.id)) {
                    ForEach(grup.kayitlar) { x in satir(x, v) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .kpZemin()
        .searchable(text: $arama, prompt: "Müşteri, ürün, not ara")
        .refreshable { await depo.yukle() }
        .navigationTitle("Finans")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Dönem", selection: $ay) {
                        Text("Tüm zamanlar").tag(String?.none)
                        ForEach(v.aylar, id: \.self) { a in Text(Gun.ayAdi(a)).tag(String?.some(a)) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(ay.map(Gun.ayAdi) ?? "Tüm zamanlar").font(.subheadline.weight(.bold))
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Renk.maviAcik, in: Capsule())
                }
                .accessibilityLabel("Dönem seç")
            }
        }
        .confirmationDialog("Kayıt silinsin mi?", isPresented: Binding(get: { silinecek != nil }, set: { if !$0 { silinecek = nil } }),
                            titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                guard let x = silinecek else { return }
                Task {
                    do {
                        if let s = x.satis { try await depo.satisSil(s.id); gezinti.bildir("Satış silindi, stoklar geri yüklendi") }
                        if let g = x.gider { try await depo.giderSil(g.id); gezinti.bildir("Gider silindi") }
                    } catch { gezinti.goster(error) }
                }
            }
        } message: {
            Text(silinecek?.satis != nil ? "Satılan hayvan/civcivler ilgili kümes/üniteye geri eklenir." : "Bu işlem geri alınamaz.")
        }
        .confirmationDialog("Kalan \(para(tahsil?.kalan ?? 0)) alındı mı?", isPresented: Binding(get: { tahsil != nil }, set: { if !$0 { tahsil = nil } }),
                            titleVisibility: .visible) {
            Button("Evet, tahsil edildi") {
                guard let s = tahsil else { return }
                Task { do { try await depo.tahsilEt(s.id); gezinti.bildir("Ödeme tahsil edildi") } catch { gezinti.goster(error) } }
            }
        }
    }

    private func ozetKarti(_ o: FinansOzeti) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(o.net >= 0 ? "Net kazanç" : "Net zarar").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                Text(para(o.net)).font(.system(size: 34, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            HStack(spacing: 10) {
                kucuk("Gelir", para(o.gelir), "\(o.satisSayisi) satış")
                kucuk("Gider", para(o.gider), "\(o.giderSayisi) kayıt")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                Renk.maviKoyu
                Circle().fill(Renk.maviOrta.opacity(0.6)).frame(width: 150, height: 150).offset(x: 40, y: -50)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func kucuk(_ b: String, _ d: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(b).font(.caption).foregroundStyle(.white.opacity(0.8))
            Text(d).font(.headline.monospacedDigit()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(a).font(.caption2).foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func kutu(_ b: String, _ d: String, _ a: String, _ r: Color, _ z: Color, _ e: @escaping () -> Void) -> some View {
        Button(action: e) {
            VStack(alignment: .leading, spacing: 2) {
                Text(b).font(.caption.weight(.heavy)).foregroundStyle(r).tracking(0.4)
                Text(d).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(r).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 2) {
                    Text(a)
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                }
                .font(.caption).foregroundStyle(Renk.metin.opacity(0.75))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(z, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func satir(_ x: FinansKaydi, _ v: Veri) -> some View {
        if let s = x.satis {
            Button { if !depo.saltOkunur { gezinti.ac(.satis(s.id)) } } label: {
                HareketSatiri(simge: "arrow.up", renk: Renk.yesil, zemin: Renk.yesilAcik, baslik: s.musteriAdi,
                              alt: s.urunOzeti.isEmpty ? "Satış" : s.urunOzeti, tutar: "+" + para(s.toplam), tutarRenk: Renk.yesil,
                              etiket: s.kalan > 0 ? para(s.kalan) + " kalan" : nil)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .swipeActions(edge: .trailing) {
                if !depo.saltOkunur {
                    Button("Sil", role: .destructive) { silinecek = x }
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if !depo.saltOkunur {
                    Button("Düzenle", systemImage: "pencil") { gezinti.ac(.satis(s.id)) }.tint(Renk.mavi)
                    if s.kalan > 0 { Button("Alındı") { tahsil = s }.tint(Renk.yesilDolgu) }
                }
            }
        } else if let g = x.gider {
            Button { if !depo.saltOkunur { gezinti.ac(.gider(g.id)) } } label: {
                HareketSatiri(simge: g.turu.simge, renk: Renk.kirmizi, zemin: Renk.kirmiziAcik, baslik: g.baslik,
                              alt: [g.turu.ad, v.kumes(g.kumesId)?.ad].compactMap { $0 }.joined(separator: " · "),
                              tutar: "−" + para(g.tutar), tutarRenk: Renk.kirmizi,
                              etiket: g.kalan > 0 ? para(g.kalan) + " borç" : nil)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .swipeActions(edge: .trailing) {
                if !depo.saltOkunur {
                    Button("Sil", role: .destructive) { silinecek = x }
                }
            }
        }
    }

    private func gunGruplari(_ v: Veri) -> [FinansGunu] {
        let a = arama.trimmingCharacters(in: .whitespaces).lowercased(with: Locale(identifier: "tr_TR"))
        func uyar(_ metin: String) -> Bool { a.isEmpty || metin.lowercased(with: Locale(identifier: "tr_TR")).contains(a) }
        var liste: [FinansKaydi] = []
        if filtre != .giderler {
            for s in v.satislar where ay == nil || s.tarih.hasPrefix(ay!) {
                let hav = ([s.musteri ?? "", s.not ?? ""] + s.urunler.map { "\($0.ad) \($0.irkAd ?? "") \($0.tip.ad)" }).joined(separator: " ")
                if uyar(hav) { liste.append(FinansKaydi(id: "s" + s.id, tarih: s.tarih, satis: s)) }
            }
        }
        if filtre != .satislar {
            for g in v.giderler where ay == nil || g.tarih.hasPrefix(ay!) {
                if uyar("\(g.aciklama ?? "") \(g.turu.ad) \(v.kumes(g.kumesId)?.ad ?? "")") {
                    liste.append(FinansKaydi(id: "g" + g.id, tarih: g.tarih, gider: g))
                }
            }
        }
        let gruplu = Dictionary(grouping: liste) { $0.tarih }
        return gruplu.keys.sorted(by: >).map { FinansGunu(id: $0, kayitlar: gruplu[$0] ?? []) }
    }

    private func gunBasligi(_ g: String) -> String {
        if g == Gun.bugun { return "Bugün" }
        if let d = Gun.coz(g), Gun.fark(d, Date()) == 1 { return "Dün" }
        return Gun.goster(g)
    }
}

// MARK: - Alacak / borç listeleri

struct AlacakListesi: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    @State private var tahsil: Satis?

    var body: some View {
        let liste = depo.veri.alacaklar
        NavigationStack {
            List {
                if liste.isEmpty {
                    BosDurum(simge: "checkmark.seal", baslik: "Bekleyen alacak yok").listRowBackground(Color.clear)
                }
                ForEach(liste) { kisi in
                    Section {
                        DisclosureGroup {
                            ForEach(kisi.satislar) { s in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(Gun.goster(s.tarih)).font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(para(s.kalan)).font(.subheadline.weight(.bold)).foregroundStyle(Renk.turuncuYazi)
                                    }
                                    Text("Toplam \(para(s.toplam))" + (s.odenen > 0 ? " · ödenen \(para(s.odenen))" : ""))
                                        .font(.caption).foregroundStyle(Renk.ikincil)
                                    if let n = s.not { Text(n).font(.caption).foregroundStyle(Renk.ikincil) }
                                    if !depo.saltOkunur {
                                        Button { tahsil = s } label: {
                                            Label("Alındı", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent).tint(Renk.yesilDolgu).controlSize(.regular)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } label: {
                            HStack {
                                IkonRozeti(simge: "person.fill", renk: Renk.turuncuYazi, zemin: Renk.turuncuAcik, boyut: 32)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(kisi.ad).font(.body.weight(.semibold))
                                    Text("\(kisi.satislar.count) kayıt").font(.caption).foregroundStyle(Renk.ikincil)
                                }
                                Spacer()
                                Text(para(kisi.toplam)).font(.body.weight(.bold).monospacedDigit()).foregroundStyle(Renk.turuncuYazi)
                            }
                        }
                    }
                }
            }
            .kpZemin()
            .navigationTitle("Alacaklarım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti") { kapat() } } }
            .confirmationDialog("Kalan \(para(tahsil?.kalan ?? 0)) alındı mı?", isPresented: Binding(get: { tahsil != nil }, set: { if !$0 { tahsil = nil } }),
                                titleVisibility: .visible) {
                Button("Evet, tahsil edildi") {
                    guard let s = tahsil else { return }
                    Task { do { try await depo.tahsilEt(s.id); gezinti.bildir("Ödeme tahsil edildi") } catch { gezinti.goster(error) } }
                }
            } message: { Text("Ödeme tam tahsil edilmiş sayılır.") }
        }
    }
}

struct BorcListesi: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    @State private var odenecek: Gider?

    var body: some View {
        let liste = depo.veri.giderler.filter { $0.kalan > 0 }
        NavigationStack {
            List {
                if liste.isEmpty {
                    BosDurum(simge: "checkmark.seal", baslik: "Bekleyen borç yok").listRowBackground(Color.clear)
                }
                ForEach(liste) { g in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(g.baslik).font(.body.weight(.semibold))
                            Spacer()
                            Text(para(g.kalan)).font(.body.weight(.bold)).foregroundStyle(Renk.kirmizi)
                        }
                        Text("\(Gun.goster(g.tarih)) · toplam \(para(g.tutar))" + (g.odenen > 0 ? " · ödenen \(para(g.odenen))" : ""))
                            .font(.caption).foregroundStyle(Renk.ikincil)
                    }
                    .swipeActions(edge: .leading) {
                        if !depo.saltOkunur { Button("Ödendi") { odenecek = g }.tint(Renk.yesilDolgu) }
                    }
                }
            }
            .kpZemin()
            .navigationTitle("Borçlarım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti") { kapat() } } }
            .confirmationDialog("Kalan \(para(odenecek?.kalan ?? 0)) ödendi mi?", isPresented: Binding(get: { odenecek != nil }, set: { if !$0 { odenecek = nil } }),
                                titleVisibility: .visible) {
                Button("Evet, ödendi") {
                    guard let g = odenecek else { return }
                    Task { do { try await depo.borcOde(g.id); gezinti.bildir("Borç ödendi olarak işaretlendi") } catch { gezinti.goster(error) } }
                }
            }
        }
    }
}
