import SwiftUI
import KumesCekirdek

struct UniteKarti: View {
    let u: Unite

    var body: some View {
        Kart {
            HStack(spacing: 12) {
                IkonRozeti(simge: u.tip == .yavruGuvercin ? "bird.fill" : "shippingbox.fill",
                           renk: Renk.camgobegi, zemin: Renk.camgobegiAcik, boyut: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.ad).font(.headline).foregroundStyle(Renk.metin).lineLimit(1)
                    Text([u.tip.ad, "\(u.aktifPartiler.count) parti", u.ortalamaYas().map { "ort. " + gunlukMetni($0) }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(Renk.ikincil).lineLimit(1)
                }
                Spacer()
                Text("\(u.adet)").font(.title.weight(.bold).monospacedDigit()).foregroundStyle(Renk.camgobegi)
            }
        }
    }
}

struct UniteDetay: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let uniteId: String
    @State private var silOnay = false
    @State private var partiSilinecek: String?

    var body: some View {
        if let u = depo.veri.unite(uniteId) {
            List {
                Section {
                    VStack(spacing: 8) {
                        Text("\(u.adet)").font(.system(size: 44, weight: .bold).monospacedDigit()).foregroundStyle(Renk.camgobegi)
                        Text("MEVCUT \(u.tip.ad.uppercased(with: Locale(identifier: "tr_TR")))")
                            .font(.caption.weight(.bold)).foregroundStyle(Renk.ikincil).tracking(0.5)
                        if let y = u.ortalamaYas() { Hap(yazi: "Ortalama yaş: \(gunlukMetni(y))", renk: Renk.camgobegi, zemin: Renk.camgobegiAcik) }
                        HStack(spacing: 24) {
                            VStack { Text("\(u.toplamGiren)").font(.title3.weight(.bold)).foregroundStyle(Renk.yesil); Text("giren").font(.caption) }
                            VStack { Text("\(u.toplamCikan)").font(.title3.weight(.bold)).foregroundStyle(Renk.kirmizi); Text("çıkan").font(.caption) }
                        }
                        .padding(.top, 4)
                        if !depo.saltOkunur {
                            Button { gezinti.ac(.partiEkle(u.id)) } label: {
                                Label("Yeni \(u.tip.ad.lowercased()) partisi", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 32)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Aktif partiler") {
                    if u.aktifPartiler.isEmpty {
                        Text("Stokta parti yok").foregroundStyle(Renk.ikincil)
                    }
                    ForEach(u.aktifPartiler, id: \.partiId) { p in
                        PartiSatiri(u: u, p: p, salt: depo.saltOkunur) { partiSilinecek = p.partiId }
                    }
                }

                if !depo.saltOkunur {
                    Section {
                        Button("Üniteyi sil", role: .destructive) { silOnay = true }
                    }
                }
            }
            .kpZemin()
            .navigationTitle(u.ad)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !depo.saltOkunur {
                    ToolbarItem(placement: .primaryAction) { Button("Düzenle") { gezinti.ac(.uniteDuzenle(u.id)) } }
                }
            }
            .confirmationDialog("\"\(u.ad)\" silinsin mi?", isPresented: $silOnay, titleVisibility: .visible) {
                Button("Üniteyi sil", role: .destructive) {
                    Task {
                        do { try await depo.uniteSil(u.id); kapat(); gezinti.bildir("Ünite silindi") } catch { gezinti.goster(error) }
                    }
                }
            } message: { Text("Bu işlem geri alınamaz.") }
            .confirmationDialog("Parti tamamen silinsin mi?", isPresented: Binding(get: { partiSilinecek != nil }, set: { if !$0 { partiSilinecek = nil } }),
                                titleVisibility: .visible) {
                Button("Partiyi sil", role: .destructive) {
                    guard let p = partiSilinecek else { return }
                    Task {
                        do { try await depo.partiSil(uniteId: u.id, partiId: p); gezinti.bildir("Parti silindi") } catch { gezinti.goster(error) }
                    }
                }
            } message: { Text("Ünite toplamından partinin kalan hayvanları düşülür.") }
        } else {
            BosDurum(simge: "shippingbox", baslik: "Ünite bulunamadı")
        }
    }
}

struct PartiSatiri: View {
    @Environment(Gezinti.self) private var gezinti
    let u: Unite
    let p: UniteHareketi
    let salt: Bool
    var sil: () -> Void

    var body: some View {
        let pid = p.partiId ?? ""
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.kaynak).font(.body.weight(.semibold))
                    Text([Gun.goster(p.tarih), partiYasi(p.tarih).map { gunlukMetni($0) }].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Renk.ikincil)
                }
                Spacer()
                Text("\(p.kalan)").font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Renk.yesil)
                    + Text(" / \(p.adet)").font(.caption).foregroundStyle(Renk.ikincil)
            }
            ProgressView(value: Double(p.kalan), total: Double(max(1, p.adet))).tint(Renk.yesilDolgu)
            if !salt {
                HStack(spacing: 8) {
                    Button("Çıkar") { gezinti.ac(.partiCikar(uniteId: u.id, partiId: pid)) }.tint(Renk.kirmizi)
                    Button("Kümese aktar") { gezinti.ac(.aktar(uniteId: u.id, partiId: pid)) }.tint(Renk.yesil)
                    Spacer()
                    Menu {
                        Button("Düzenle", systemImage: "pencil") { gezinti.ac(.partiDuzenle(uniteId: u.id, partiId: pid)) }
                        Button("Partiyi sil", systemImage: "trash", role: .destructive, action: sil)
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Parti işlemleri")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formlar

struct UniteFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let uniteId: String?
    @State private var ad = ""
    @State private var tip: UniteTipi = .civciv
    @State private var adet = 0
    @State private var tarih = Gun.bugun
    @State private var calisiyor = false
    @State private var hazir = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ünite adı (örn. Isıtıcılı kafes)", text: $ad)
                    Picker("Tür", selection: $tip) {
                        ForEach(UniteTipi.allCases) { t in Text(t.ad).tag(t) }
                    }
                }
                if uniteId == nil {
                    Section {
                        SayiSatiri(baslik: "Başlangıç adedi", deger: $adet)
                        if adet > 0 { GunSecici(baslik: "Tarih", gun: $tarih) }
                    } footer: { Text("İsteğe bağlı. Kuluçka çıkımları üniteye ayrı parti olarak eklenir.") }
                }
            }
            .kpZemin()
            .navigationTitle(uniteId == nil ? "Yeni ünite" : "Ünite düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Kaydet", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
            .onAppear {
                guard !hazir else { return }
                hazir = true
                if let u = depo.veri.unite(uniteId) { ad = u.ad; tip = u.tip }
            }
        }
    }

    private func kaydet() async {
        let a = ad.trimmingCharacters(in: .whitespaces)
        guard !a.isEmpty else { gezinti.goster(KuralHatasi("Ünite adı gerekli!")); return }
        do {
            if let uniteId { try await depo.uniteAdiDegistir(uniteId, ad: a, tip: tip) }
            else { try await depo.uniteEkle(ad: a, tip: tip, adet: adet, tarih: tarih) }
            kapat()
            gezinti.bildir(uniteId == nil ? "Ünite oluşturuldu" : "Ünite güncellendi")
        } catch { gezinti.goster(error) }
    }
}

struct PartiEkleFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let uniteId: String
    @State private var adet = 1
    @State private var kaynak = ""
    @State private var tarih = Gun.bugun
    @State private var not = ""
    @State private var calisiyor = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SayiSatiri(baslik: "Adet", deger: $adet)
                    TextField("Kaynak / ırk (örn. Brahma)", text: $kaynak)
                    GunSecici(baslik: "Çıkış / alış tarihi", gun: $tarih)
                }
                Section("Not") { TextField("İsteğe bağlı", text: $not) }
            }
            .kpZemin()
            .navigationTitle("Yeni parti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Ekle", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
        }
        .presentationDetents([.medium, .large])
    }

    private func kaydet() async {
        do {
            try await depo.partiEkle(uniteId: uniteId, adet: adet, kaynak: kaynak, not: not.trimmingCharacters(in: .whitespaces), tarih: tarih)
            kapat(); gezinti.bildir("\(adet) adet eklendi")
        } catch { gezinti.goster(error) }
    }
}

struct PartiCikarFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let uniteId: String
    let partiId: String
    @State private var adet = 1
    @State private var not = ""
    @State private var tarih = Gun.bugun
    @State private var calisiyor = false

    var body: some View {
        let p = depo.veri.unite(uniteId)?.parti(partiId)
        NavigationStack {
            Form {
                Section {
                    SayiSatiri(baslik: "Adet", not: "kalan \(p?.kalan ?? 0)", deger: $adet, ust: p?.kalan ?? 0)
                    GunSecici(baslik: "Tarih", gun: $tarih)
                } header: { Text("\(p?.kaynak ?? "Parti") partisinden çıkar") }
                Section("Sebep") { TextField("Ölüm/Kayıp", text: $not) }
            }
            .kpZemin()
            .navigationTitle("Partiden çıkar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Çıkar", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
        }
        .presentationDetents([.medium, .large])
    }

    private func kaydet() async {
        do {
            try await depo.partidenCikar(uniteId: uniteId, partiId: partiId, adet: adet, not: not, tarih: tarih)
            kapat(); gezinti.bildir("\(adet) adet çıkarıldı")
        } catch { gezinti.goster(error) }
    }
}

struct PartiDuzenleFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let uniteId: String
    let partiId: String
    @State private var kaynak = ""
    @State private var adet = 0
    @State private var kalan = 0
    @State private var tarih = Gun.bugun
    @State private var not = ""
    @State private var calisiyor = false
    @State private var hazir = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kaynak / ırk", text: $kaynak)
                    SayiSatiri(baslik: "Başlangıç adedi", deger: $adet)
                    SayiSatiri(baslik: "Kalan", deger: $kalan, ust: adet)
                    GunSecici(baslik: "Tarih", gun: $tarih)
                }
                Section("Not") { TextField("İsteğe bağlı", text: $not) }
            }
            .kpZemin()
            .navigationTitle("Parti düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Kaydet", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
            .onAppear {
                guard !hazir, let p = depo.veri.unite(uniteId)?.parti(partiId) else { return }
                hazir = true
                kaynak = p.kaynak; adet = p.adet; kalan = p.kalan; tarih = p.tarih ?? Gun.bugun; not = p.not ?? ""
            }
        }
    }

    private func kaydet() async {
        do {
            try await depo.partiDuzenle(uniteId: uniteId, partiId: partiId, kaynak: kaynak, adet: adet, kalan: kalan, tarih: tarih, not: not)
            kapat(); gezinti.bildir("Parti güncellendi")
        } catch { gezinti.goster(error) }
    }
}

struct AktarFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let uniteId: String
    let partiId: String
    @State private var kumesId = ""
    @State private var irkId = "__yeni"
    @State private var yeniIrk = ""
    @State private var erkek = 0
    @State private var disi = 0
    @State private var tarih = Gun.bugun
    @State private var not = ""
    @State private var calisiyor = false
    @State private var hazir = false

    var body: some View {
        let v = depo.veri
        let p = v.unite(uniteId)?.parti(partiId)
        let k = v.kumes(kumesId)
        NavigationStack {
            Form {
                Section {
                    Picker("Kümes", selection: $kumesId) {
                        ForEach(v.kumesler) { k in Text(k.ad).tag(k.id) }
                    }
                    Picker("Irk", selection: $irkId) {
                        ForEach(k?.irklar ?? []) { r in Text(r.ad.isEmpty ? "İsimsiz" : r.ad).tag(r.id) }
                        Text("Yeni ırk oluştur").tag("__yeni")
                    }
                    if irkId == "__yeni" { TextField("Yeni ırk adı", text: $yeniIrk) }
                } header: { Text("\(p?.kaynak ?? "Parti") · kalan \(p?.kalan ?? 0)") }
                Section {
                    SayiSatiri(baslik: "Erkek", deger: $erkek, ust: p?.kalan ?? 0)
                    SayiSatiri(baslik: "Dişi", deger: $disi, ust: p?.kalan ?? 0)
                    GunSecici(baslik: "Tarih", gun: $tarih)
                } footer: { Text("Toplam \(erkek + disi) / \(p?.kalan ?? 0). Partinin tarihi hayvanların doğum tarihi olarak taşınır.") }
                Section("Not") { TextField("İsteğe bağlı", text: $not) }
            }
            .kpZemin()
            .navigationTitle("Kümese aktar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Aktar", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
            .onAppear {
                guard !hazir else { return }
                hazir = true
                kumesId = v.kumesler.first?.id ?? ""
                yeniIrk = p?.kaynak ?? ""
            }
            .onChange(of: kumesId) { irkId = "__yeni" }
        }
    }

    private func kaydet() async {
        guard !kumesId.isEmpty else { gezinti.goster(KuralHatasi("Önce bir kümes oluşturmalısınız!")); return }
        do {
            try await depo.kumeseAktar(uniteId: uniteId, partiId: partiId, kumesId: kumesId, irkId: irkId == "__yeni" ? nil : irkId,
                                       yeniIrk: yeniIrk, erkek: erkek, disi: disi, not: not, tarih: tarih)
            kapat(); gezinti.bildir("\(erkek + disi) hayvan kümese aktarıldı")
        } catch { gezinti.goster(error) }
    }
}
