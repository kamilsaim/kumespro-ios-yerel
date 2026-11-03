import SwiftUI
import KumesCekirdek

struct KuluckaEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @State private var tamamlananAcik = false
    @State private var silinecek: Kulucka?

    var body: some View {
        let v = depo.veri
        let aktif = v.aktifKuluckalar.sorted { $0.durum().gecikme > $1.durum().gecikme }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(aktif.count) devam ediyor · \(v.biten.count) tamamlandı")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Renk.ikincil)
                if v.kuluckalar.isEmpty {
                    BosDurum(simge: "oval.portrait", baslik: "Henüz kuluçka yok",
                             metin: "Kuluçka başlatınca sepete alma ve çıkım günleri için hatırlatma kurulur.",
                             dugme: depo.saltOkunur ? nil : "Kuluçka başlat") { gezinti.ac(.kulucka(nil)) }
                }
                ForEach(aktif) { k in
                    AktifKuluckaKarti(k: k, salt: depo.saltOkunur) { silinecek = k }
                }
                if !v.biten.isEmpty {
                    Button {
                        withAnimation(.snappy) { tamamlananAcik.toggle() }
                    } label: {
                        HStack {
                            Text("Tamamlananlar (\(v.biten.count))").font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.down").rotationEffect(.degrees(tamamlananAcik ? 180 : 0))
                        }
                        .foregroundStyle(Renk.metin.opacity(0.8))
                        .padding(14)
                        .background(Renk.kartIkinci, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    if tamamlananAcik {
                        ForEach(v.biten.reversed()) { k in BitenKuluckaKarti(k: k, salt: depo.saltOkunur) { silinecek = k } }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 12)
        }
        .background(Renk.zemin)
        .refreshable { await depo.yukle() }
        .navigationTitle("Kuluçka")
        .toolbar {
            if !depo.saltOkunur {
                ToolbarItem(placement: .primaryAction) {
                    Button { gezinti.ac(.kulucka(nil)) } label: { Image(systemName: "plus").fontWeight(.bold) }
                        .accessibilityLabel("Kuluçka başlat")
                }
            }
        }
        .confirmationDialog("\"\(silinecek?.ad ?? "")\" silinsin mi?", isPresented: Binding(get: { silinecek != nil }, set: { if !$0 { silinecek = nil } }),
                            titleVisibility: .visible) {
            Button("Kuluçkayı sil", role: .destructive) {
                guard let k = silinecek else { return }
                Task { do { try await depo.kuluckaSil(k.id); gezinti.bildir("Kuluçka silindi") } catch { gezinti.goster(error) } }
            }
        }
    }
}

struct AktifKuluckaKarti: View {
    @Environment(Gezinti.self) private var gezinti
    @Environment(Depo.self) private var depo
    let k: Kulucka
    let salt: Bool
    var sil: () -> Void

    var body: some View {
        let d = k.durum()
        if d.gecikti {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(d.gecikme) GÜN GECİKTİ").font(.caption.weight(.heavy)).tracking(0.5).foregroundStyle(.white.opacity(0.9))
                        Text(k.ad).font(.title3.weight(.bold)).foregroundStyle(.white)
                        Text("\(k.yumurta) yumurta · Çıkım \(d.cikim.map { Gun.kisa($0) } ?? "-") idi")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    menu.foregroundStyle(.white)
                }
                if !salt {
                    Button { gezinti.ac(.cikim(k.id)) } label: {
                        Text("Çıkım sonucunu gir").font(.headline).foregroundStyle(Renk.kirmiziDolgu)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Renk.kirmiziDolgu, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(k.ad).font(.title3.weight(.bold)).foregroundStyle(Renk.metin)
                        Text("\(k.yumurta) yumurta · \(k.sure) gün").font(.subheadline).foregroundStyle(Renk.metin.opacity(0.75))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(d.kalan == 0 ? "Bugün" : "\(d.kalan)").font(.system(size: 30, weight: .bold).monospacedDigit())
                            .foregroundStyle(Renk.turuncuYazi)
                        Text(d.kalan == 0 ? "çıkım günü" : "gün kaldı").font(.caption.weight(.semibold)).foregroundStyle(Renk.turuncuYazi)
                    }
                    menu.foregroundStyle(Renk.turuncuYazi)
                }
                GunSeridi(sure: k.sure, gecen: d.gecen)
                HStack {
                    adim("Başladı", d.baslangic, hiza: .leading)
                    Spacer()
                    adim("Sepete al", d.sepet, hiza: .center)
                    Spacer()
                    adim("Çıkım", d.cikim, hiza: .trailing, renk: Renk.yesil)
                }
                if !k.kaynaklar.isEmpty {
                    Text(k.kaynakOzeti(depo.veri)).font(.caption).foregroundStyle(Renk.metin.opacity(0.7)).lineLimit(2)
                }
                if !salt, d.kalan <= 3 {
                    Button { gezinti.ac(.cikim(k.id)) } label: {
                        Label("Çıkım gir", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent).tint(Renk.turuncu)
                }
            }
            .padding(16)
            .background(Renk.turuncuAcik, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    @ViewBuilder private var menu: some View {
        if !salt {
            Menu {
                Button("Çıkım gir", systemImage: "checkmark.circle") { gezinti.ac(.cikim(k.id)) }
                Button("Düzenle", systemImage: "pencil") { gezinti.ac(.kulucka(k.id)) }
                Button("Sil", systemImage: "trash", role: .destructive, action: sil)
            } label: {
                Image(systemName: "ellipsis.circle.fill").font(.title2).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Kuluçka işlemleri")
        }
    }

    private func adim(_ ad: String, _ t: Date?, hiza: HorizontalAlignment, renk: Color = Renk.turuncuYazi) -> some View {
        VStack(alignment: hiza, spacing: 1) {
            Text(ad).font(.caption.weight(.semibold)).foregroundStyle(renk)
            Text(t.map { Gun.kisa($0) } ?? "-").font(.subheadline.weight(.bold)).foregroundStyle(Renk.metin)
        }
    }
}

/// Gün gün ilerleme şeridi: geçen günler turuncu, bugün çerçeveli, son 3 gün (sepet) yeşil tonlu.
struct GunSeridi: View {
    let sure: Int
    let gecen: Int

    var body: some View {
        let n = min(max(sure, 1), 45)
        let bugun = sure > 0 ? Int((Double(gecen) / Double(sure) * Double(n)).rounded(.down)) : 0
        HStack(spacing: n > 30 ? 2 : 3) {
            ForEach(0..<n, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(renk(i, bugun: bugun, n: n))
                    .overlay {
                        if i == min(bugun, n - 1) && gecen < sure {
                            RoundedRectangle(cornerRadius: 3).stroke(Renk.turuncuYazi, lineWidth: 2).padding(-2)
                        }
                    }
            }
        }
        .frame(height: 12)
        .accessibilityElement()
        .accessibilityLabel("\(sure) günün \(gecen) günü geçti")
    }

    private func renk(_ i: Int, bugun: Int, n: Int) -> Color {
        if i < bugun { return Renk.turuncuParlak }
        if i >= n - 3 { return Renk.yesilDolgu.opacity(i == n - 1 ? 1 : 0.45) }
        return Renk.turuncuIz
    }
}

struct BitenKuluckaKarti: View {
    let k: Kulucka
    let salt: Bool
    var sil: () -> Void

    var body: some View {
        Kart {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.ad).font(.headline)
                        Text("\(Gun.goster(k.baslangic)) · \(k.sure) gün · \(k.yumurta) yumurta")
                            .font(.caption).foregroundStyle(Renk.ikincil)
                    }
                    Spacer()
                    if !salt {
                        Menu { Button("Sil", systemImage: "trash", role: .destructive, action: sil) } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Kuluçka işlemleri")
                    }
                }
                if let c = k.cikim {
                    AkisDuzeni(aralik: 6) {
                        Hap(yazi: "\(c.civciv) çıktı", renk: Renk.yesil, zemin: Renk.yesilAcik)
                        Hap(yazi: "\(c.bos) boş", renk: Renk.ikincil, zemin: Renk.kartIkinci)
                        Hap(yazi: "\(c.olu) ölü", renk: Renk.kirmizi, zemin: Renk.kirmiziAcik)
                        if let v = k.verim { Hap(yazi: "%\(v) verim") }
                    }
                    if c.kaynaklar.count > 1 {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(c.kaynaklar.enumerated()), id: \.offset) { _, r in
                                Text("\(r.metin("ad") ?? "Kaynak"): \(r["civciv"]?.int ?? 0) çıkan · \(r["olu"]?.int ?? 0) ölü · \(r["bos"]?.int ?? 0) boş")
                                    .font(.caption).foregroundStyle(Renk.ikincil)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Kuluçka formu

struct KuluckaFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let kuluckaId: String?

    @State private var ad = ""
    @State private var baslangic = Gun.bugun
    @State private var sure = 21
    @State private var ozelSure = false
    @State private var kaynaklar: [YumurtaKaynagi] = []
    @State private var not = ""
    @State private var calisiyor = false
    @State private var hazir = false

    private let standart = [17, 18, 21, 24, 28, 30]

    var body: some View {
        let v = depo.veri
        NavigationStack {
            Form {
                Section {
                    TextField("Kuluçka adı (örn. Mart Brahma)", text: $ad)
                    GunSecici(baslik: "Başlangıç", gun: $baslangic)
                    Picker("Süre", selection: Binding(get: { ozelSure ? 0 : sure }, set: { y in
                        if y == 0 { ozelSure = true } else { ozelSure = false; sure = y }
                    })) {
                        Text("17 gün · bıldırcın").tag(17)
                        Text("18 gün · güvercin").tag(18)
                        Text("21 gün · tavuk").tag(21)
                        Text("24 gün · keklik").tag(24)
                        Text("28 gün · hindi, ördek").tag(28)
                        Text("30 gün · kaz").tag(30)
                        Text("Özel…").tag(0)
                    }
                    if ozelSure { SayiSatiri(baslik: "Gün", deger: $sure, ust: 90) }
                }
                Section {
                    ForEach(kaynaklar) { r in
                        VStack(spacing: 8) {
                            Picker("Kümes", selection: kaynakBag(r.id, kumes: true)) {
                                Text("Serbest").tag("")
                                ForEach(v.kumesler) { k in Text(k.ad).tag(k.id) }
                            }
                            if let k = v.kumes(r.kumesId), !k.irklar.isEmpty {
                                Picker("Irk", selection: kaynakBag(r.id, kumes: false)) {
                                    Text("Genel").tag("")
                                    ForEach(k.irklar) { i in Text(i.ad).tag(i.id) }
                                }
                            }
                            TextField("Açıklama (örn. komşudan)", text: aciklamaBag(r.id))
                            SayiSatiri(baslik: "Yumurta", deger: adetBag(r.id))
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { kaynaklar.remove(atOffsets: $0) }
                    Button { kaynaklar.append(YumurtaKaynagi(kumesId: v.kumesler.first?.id)) } label: {
                        Label("Kaynak ekle", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Yumurta kaynakları · toplam \(kaynaklar.reduce(0) { $0 + $1.adet })")
                } footer: { Text("Çıkımda her kaynak için sonuç ayrı girilir. Silmek için sola kaydır.") }
                Section("Not") { TextField("İsteğe bağlı", text: $not, axis: .vertical) }
            }
            .kpZemin()
            .navigationTitle(kuluckaId == nil ? "Kuluçka başlat" : "Kuluçka düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Kaydet", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
            .onAppear(perform: doldur)
        }
    }

    private func indeks(_ id: String) -> Int? { kaynaklar.firstIndex { $0.id == id } }

    private func kaynakBag(_ id: String, kumes: Bool) -> Binding<String> {
        Binding(get: {
            guard let i = indeks(id) else { return "" }
            return (kumes ? kaynaklar[i].kumesId : kaynaklar[i].irkId) ?? ""
        }, set: { y in
            guard let i = indeks(id) else { return }
            if kumes { kaynaklar[i].kumesId = y.isEmpty ? nil : y; kaynaklar[i].irkId = nil }
            else { kaynaklar[i].irkId = y.isEmpty ? nil : y }
        })
    }

    private func aciklamaBag(_ id: String) -> Binding<String> {
        Binding(get: { indeks(id).map { kaynaklar[$0].aciklama } ?? "" },
                set: { y in if let i = indeks(id) { kaynaklar[i].aciklama = y } })
    }

    private func adetBag(_ id: String) -> Binding<Int> {
        Binding(get: { indeks(id).map { kaynaklar[$0].adet } ?? 0 },
                set: { y in if let i = indeks(id) { kaynaklar[i].adet = y } })
    }

    private func doldur() {
        guard !hazir else { return }
        hazir = true
        if let k = depo.veri.kuluckalar.first(where: { $0.id == kuluckaId }) {
            ad = k.ad; baslangic = k.baslangic; sure = k.sure; ozelSure = !standart.contains(k.sure); not = k.not ?? ""
            kaynaklar = k.kaynaklar
            if kaynaklar.isEmpty, k.toplamYumurta > 0 { kaynaklar = [YumurtaKaynagi(kumesId: nil, adet: k.toplamYumurta)] }
        } else {
            kaynaklar = [YumurtaKaynagi(kumesId: depo.veri.kumesler.first?.id)]
        }
    }

    private func kaydet() async {
        let a = ad.trimmingCharacters(in: .whitespaces)
        guard !a.isEmpty else { gezinti.goster(KuralHatasi("Kuluçka adı gereklidir!")); return }
        guard !kaynaklar.isEmpty else { gezinti.goster(KuralHatasi("En az bir yumurta kaynağı ekleyin!")); return }
        guard kaynaklar.allSatisfy({ $0.adet >= 1 }) else { gezinti.goster(KuralHatasi("Tüm kaynaklar için adet girin!")); return }
        guard sure >= 1 else { gezinti.goster(KuralHatasi("Geçerli kuluçka süresi girin!")); return }
        let n = not.trimmingCharacters(in: .whitespaces)
        var k = depo.veri.kuluckalar.first(where: { $0.id == kuluckaId })
            ?? Kulucka(ad: a, baslangic: baslangic, sure: sure, kaynaklar: kaynaklar)
        k.ad = a; k.baslangic = baslangic; k.sure = sure; k.kaynaklar = kaynaklar; k.not = n.isEmpty ? nil : n
        do {
            try await depo.kuluckaKaydet(k)
            kapat(); gezinti.bildir("Kuluçka kaydedildi")
        } catch { gezinti.goster(error) }
    }
}

// MARK: - Çıkım formu

struct CikimFormu: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(\.dismiss) private var kapat
    let kuluckaId: String

    @State private var satirlar: [CikimKaynagi] = []
    @State private var tarih = Gun.bugun
    @State private var not = ""
    @State private var uniteId = ""
    @State private var yeniUnite = ""
    @State private var yeniTip: UniteTipi = .civciv
    @State private var calisiyor = false
    @State private var hazir = false

    var body: some View {
        let v = depo.veri
        let k = v.kuluckalar.first { $0.id == kuluckaId }
        let tY = satirlar.reduce(0) { $0 + $1.yumurta }, tC = satirlar.reduce(0) { $0 + $1.civciv }
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 0) {
                        ozet("\(tY)", "yumurta", Renk.metin)
                        ozet("\(tC)", "çıkan", Renk.yesil)
                        ozet("\(satirlar.reduce(0) { $0 + $1.olu })", "ölü", Renk.kirmizi)
                        ozet("%\(tY > 0 ? Int((Double(tC) / Double(tY) * 100).rounded()) : 0)", "verim", Renk.turuncuYazi)
                    }
                    .padding(.vertical, 4)
                }
                ForEach(satirlar.indices, id: \.self) { i in
                    Section {
                        SayiSatiri(baslik: "Çıkan civciv", deger: $satirlar[i].civciv, ust: satirlar[i].yumurta)
                        SayiSatiri(baslik: "Ölü", deger: $satirlar[i].olu, ust: satirlar[i].yumurta)
                        SayiSatiri(baslik: "Boş", deger: $satirlar[i].bos, ust: satirlar[i].yumurta)
                    } header: {
                        Text("\(satirlar[i].ad) · \(satirlar[i].yumurta) yumurta")
                    } footer: {
                        let f = satirlar[i].fark
                        Text(f == 0 ? "Tamam" : (f > 0 ? "\(f) yumurta girilmedi" : "\(-f) fazla girildi"))
                            .foregroundStyle(f == 0 ? Renk.yesil : Renk.turuncuYazi)
                    }
                }
                Section {
                    GunSecici(baslik: "Çıkım tarihi", gun: $tarih)
                    Picker("Civcivler nereye?", selection: $uniteId) {
                        Text("Üniteye ekleme").tag("")
                        ForEach(v.uniteler) { u in Text("\(u.ad) (\(u.adet))").tag(u.id) }
                        Text("Yeni ünite oluştur…").tag("__yeni")
                    }
                    if uniteId == "__yeni" {
                        TextField("Yeni ünite adı", text: $yeniUnite)
                        Picker("Tür", selection: $yeniTip) { ForEach(UniteTipi.allCases) { t in Text(t.ad).tag(t) } }
                    }
                } footer: { Text("Çıkan civcivler seçilen üniteye kaynak başına ayrı parti olarak eklenir.") }
                Section("Not") { TextField("İsteğe bağlı", text: $not) }
            }
            .kpZemin()
            .navigationTitle(k.map { "Çıkım · \($0.ad)" } ?? "Çıkım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { FormAracCubugu(baslik: "Kaydet", calisiyor: $calisiyor, kaydet: kaydet, vazgec: { kapat() }) }
            .onAppear {
                guard !hazir else { return }
                hazir = true
                satirlar = v.cikimSatirlari(kuluckaId: kuluckaId)
                if let t = k?.cikim?.tarih { tarih = t }
                not = k?.cikim?.not ?? ""
                uniteId = v.uniteler.first?.id ?? ""
            }
        }
    }

    private func ozet(_ d: String, _ e: String, _ r: Color) -> some View {
        VStack(spacing: 2) {
            Text(d).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(r)
            Text(e).font(.caption).foregroundStyle(Renk.ikincil)
        }
        .frame(maxWidth: .infinity)
    }

    private func kaydet() async {
        let yeni = uniteId == "__yeni"
        if yeni, yeniUnite.trimmingCharacters(in: .whitespaces).isEmpty {
            gezinti.goster(KuralHatasi("Yeni ünite için ad girin!")); return
        }
        do {
            let (toplam, uniteAdi) = try await depo.cikimKaydet(
                kuluckaId: kuluckaId, satirlar: satirlar, tarih: tarih, not: not,
                uniteId: yeni || uniteId.isEmpty ? nil : uniteId, yeniUniteAdi: yeni ? yeniUnite : nil, yeniUniteTipi: yeniTip)
            kapat()
            gezinti.bildir(uniteAdi.map { "\(toplam) civciv \($0) ünitesine eklendi" } ?? "Çıkım kaydedildi")
        } catch { gezinti.goster(error) }
    }
}
