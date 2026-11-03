import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import KumesCekirdek

/// Paylaşılacak dosya (yedek / Excel).
struct PaylasimDosyasi: Identifiable {
    let id = UUID()
    let url: URL
    let yedek: Bool
}

/// Sistem paylaşım menüsü; tamamlanınca bildirir (iptal edilirse false).
struct PaylasimPenceresi: UIViewControllerRepresentable {
    let url: URL
    var bitti: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, tamam, _, _ in bitti(tamam) }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct AyarlarEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(Oturum.self) private var oturum
    @Environment(\.dismiss) private var kapat
    @Environment(\.openURL) private var ac

    @State private var bildirimDurumu: UNAuthorizationStatus = .notDetermined
    @State private var bekleyen = 0
    @State private var paylasim: PaylasimDosyasi?
    @State private var cikisOnay = false
    @State private var dosyaSec = false
    @State private var yuklenecek: Yedek?
    @State private var geriYukleniyor = false

    var body: some View {
        let g = oturum.gorunum
        let v = depo.veri
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(g.harf).font(.title2.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 54, height: 54).background(Renk.turuncuParlak, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.ad).font(.headline).lineLimit(1).truncationMode(.middle)
                            Text(g.alt).font(.subheadline).foregroundStyle(Renk.ikincil)
                        }
                    }
                    .padding(.vertical, 4)
                    HStack(spacing: 0) {
                        sayi("\(v.kumesler.count)", "kümes")
                        sayi("\(v.kuluckalar.count)", "kuluçka")
                        sayi("\(v.satislar.count)", "satış")
                        sayi("\(v.giderler.count)", "gider")
                    }
                }

                Section {
                    bildirimSatiri
                } header: { Text("Kuluçka hatırlatmaları") } footer: {
                    Text("Sepete alma (çıkımdan 3 gün önce), çıkım günü ve çıkım girilmediyse 2 gün sonra, sabah 08:00'de bildirim gelir.")
                }

                Section {
                    yedekDurumu
                    Button { yedekAl() } label: { Label("JSON yedek al", systemImage: "externaldrive.fill.badge.icloud") }
                        .disabled(depo.saltOkunur)
                    Menu {
                        ForEach(RaporTipi.allCases) { t in Button(t.ad) { excel(t) } }
                    } label: { Label("Excel (CSV) raporu", systemImage: "tablecells") }
                    Button { dosyaSec = true } label: {
                        HStack {
                            Label("Yedekten geri yükle", systemImage: "arrow.counterclockwise.icloud")
                            if geriYukleniyor { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(depo.saltOkunur || geriYukleniyor)
                } header: { Text("Yedek ve rapor") } footer: {
                    Text("Geri yükleme mevcut verilerin yerine yedektekileri koyar; mevcut veriler önce sezon arşivine kaydedilir. Yedek dosyası web uygulamasında da kullanılabilir.")
                }

                Section {
                    NavigationLink { SezonlarEkrani(kapatUst: { kapat() }) } label: { Label("Sezon arşivi", systemImage: "archivebox") }
                    if !depo.saltOkunur {
                        NavigationLink { YeniSezonEkrani(kapatUst: { kapat() }) } label: { Label("Yeni sezon başlat", systemImage: "leaf") }
                        NavigationLink { YilSonuEkrani(kapatUst: { kapat() }) } label: { Label("Yıl sonu — yeni döneme geç", systemImage: "calendar.badge.clock") }
                    }
                } header: { Text("Sezon") } footer: {
                    Text("Her iki işlemde de mevcut veriler önce arşive kaydedilir; arşivden geri bakılabilir.")
                }

                Section("Destek") {
                    Link(destination: Sabitler.gizlilik) { Label("Gizlilik politikası", systemImage: "hand.raised.fill") }
                    Button { ac(URL(string: "mailto:\(Sabitler.destek)?subject=K%C3%BCmesPro%20iOS")!) } label: {
                        Label("Bize yazın", systemImage: "envelope.fill")
                    }
                }

                Section {
                    Button("Çıkış yap") { cikisOnay = true }
                    NavigationLink { HesapSilEkrani() } label: { Text("Hesabımı sil").foregroundStyle(Renk.kirmizi) }
                } footer: {
                    Text("KümesPro \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))")
                        .frame(maxWidth: .infinity).padding(.top, 8)
                }
            }
            .kpZemin()
            .navigationTitle("Hesap ve ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Bitti") { kapat() } } }
            .task { await bildirimTazele() }
            .sheet(item: $paylasim) { p in
                PaylasimPenceresi(url: p.url) { tamam in
                    if tamam && p.yedek { Task { await oturum.yedekAlindi() } }
                }
                .presentationDetents([.medium, .large])
            }
            .fileImporter(isPresented: $dosyaSec, allowedContentTypes: [.json]) { sonuc in
                do { yuklenecek = try yedekOku(sonuc.get()) } catch { gezinti.goster(error) }
            }
            .confirmationDialog("Yedek geri yüklensin mi?", isPresented: Binding(get: { yuklenecek != nil }, set: { if !$0 { yuklenecek = nil } }),
                                titleVisibility: .visible, presenting: yuklenecek) { y in
                Button("Evet, geri yükle", role: .destructive) { geriYukle(y) }
            } message: { y in
                Text(yedekOzeti(y))
            }
            .confirmationDialog("Çıkış yapılsın mı?", isPresented: $cikisOnay, titleVisibility: .visible) {
                Button("Çıkış yap", role: .destructive) { kapat(); Task { await oturum.cikis() } }
            }
        }
    }

    private func sayi(_ d: String, _ e: String) -> some View {
        VStack(spacing: 1) {
            Text(d).font(.headline.monospacedDigit())
            Text(e).font(.caption).foregroundStyle(Renk.ikincil)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var bildirimSatiri: some View {
        switch bildirimDurumu {
        case .authorized, .provisional, .ephemeral:
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bildirimler açık").foregroundStyle(Renk.yesil).fontWeight(.semibold)
                    Text(bekleyen > 0 ? "Kurulu hatırlatma: \(bekleyen)" : "Aktif kuluçka eklediğinde otomatik kurulur.")
                        .font(.caption).foregroundStyle(Renk.ikincil)
                }
            } icon: { Image(systemName: "bell.badge.fill").foregroundStyle(Renk.yesil) }
        case .denied:
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bildirimler kapalı").fontWeight(.semibold)
                    Text("Açmak için iPhone Ayarlar → KümesPro → Bildirimler").font(.caption).foregroundStyle(Renk.ikincil)
                }
            } icon: { Image(systemName: "bell.slash.fill").foregroundStyle(Renk.kirmizi) }
            Button("Ayarları aç") {
                if let u = URL(string: UIApplication.openNotificationSettingsURLString) { ac(u) }
            }
        default:
            Button {
                Task {
                    await YerelBildirim.izinIste()
                    depo.yerelleriTazele()
                    try? await Task.sleep(for: .milliseconds(400))
                    await bildirimTazele()
                }
            } label: { Label("Bildirimlere izin ver", systemImage: "bell.fill") }
        }
    }

    @ViewBuilder private var yedekDurumu: some View {
        if let g = oturum.yedekGunOnce {
            if g >= Sabitler.yedekHatirlatmaGun {
                Label("Son yedek \(g) gün önce alındı. Yeni bir yedek önerilir.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Renk.turuncuYazi).font(.subheadline)
            } else {
                Label("Son yedek: \(g == 0 ? "bugün" : "\(g) gün önce")", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Renk.yesil).font(.subheadline)
            }
        } else {
            Label("Henüz hiç yedek almadın. Telefon kaybı veya yanlış silme için yedek önerilir.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Renk.turuncuYazi).font(.subheadline)
        }
    }

    private func bildirimTazele() async {
        bildirimDurumu = await YerelBildirim.durum()
        bekleyen = await YerelBildirim.bekleyenSayisi()
    }

    private func dosyaYaz(_ ad: String, _ veri: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(ad)
        do { try veri.write(to: url, options: .atomic); return url } catch { gezinti.goster(error); return nil }
    }

    private func yedekAl() {
        Task {
            await depo.sezonlariYukle()
            let y = depo.veri.yedekJSON(eposta: oturum.kullanici?.email, sezonlar: depo.sezonlar)
            if let u = dosyaYaz(y.dosya, y.veri) { paylasim = PaylasimDosyasi(url: u, yedek: true) }
        }
    }

    private func yedekOku(_ url: URL) throws -> Yedek {
        let izin = url.startAccessingSecurityScopedResource()
        defer { if izin { url.stopAccessingSecurityScopedResource() } }
        return try Yedek(dosya: Data(contentsOf: url))
    }

    private func yedekOzeti(_ y: Yedek) -> String {
        let v = y.veri
        var m = ""
        if let t = y.tarih, let d = ISO8601DateFormatter.kesirli.date(from: t) ?? ISO8601DateFormatter().date(from: t) {
            m += "Yedek tarihi: \(Gun.goster(d))\n"
        }
        m += "\(v.kumesler.count) kümes, \(v.kuluckalar.count) kuluçka, \(v.uniteler.count) ünite, \(v.satislar.count) satış, \(v.giderler.count) gider"
        if !y.sezonlar.isEmpty { m += ", \(y.sezonlar.count) sezon arşivi" }
        m += ".\n\nMevcut kümes, kuluçka, ünite, satış ve giderlerin yerine bunlar geçecek. Mevcut veriler önce \"Yedek öncesi\" adıyla sezon arşivine kaydedilir."
        return m
    }

    private func geriYukle(_ y: Yedek) {
        geriYukleniyor = true
        Task {
            do {
                let n = try await depo.yedekYukle(y)
                kapat(); gezinti.sekme = .ozet
                gezinti.mesaj = Mesaj(baslik: "Yedek yüklendi", metin: "\(n) kayıt geri yüklendi. Önceki veriler sezon arşivinde duruyor.")
            } catch { gezinti.goster(error) }
            geriYukleniyor = false
        }
    }

    private func excel(_ t: RaporTipi) {
        let r = depo.veri.csvRaporu(t)
        if let u = dosyaYaz(r.dosya, Data(r.icerik.utf8)) { paylasim = PaylasimDosyasi(url: u, yedek: false) }
    }
}

private extension ISO8601DateFormatter {
    static let kesirli: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - Sezon arşivi

struct SezonlarEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    var kapatUst: () -> Void
    @State private var yukleniyor = true
    @State private var silinecek: Sezon?

    var body: some View {
        List {
            if yukleniyor {
                ProgressView().frame(maxWidth: .infinity)
            } else if depo.sezonlar.isEmpty {
                BosDurum(simge: "archivebox", baslik: "Arşivlenmiş sezon yok",
                         metin: "Yeni sezon ya da yıl sonu işleminde veriler buraya kaydedilir.")
                    .listRowBackground(Color.clear)
            }
            ForEach(depo.sezonlar) { s in
                Button {
                    depo.sezonGor(s)
                    kapatUst()
                    gezinti.sekme = .ozet
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.ad).font(.body.weight(.semibold)).foregroundStyle(Renk.metin)
                        Text("\(Gun.goster(s.tarih)) · \(s.satisSayisi) satış · \(s.kumesSayisi) kümes")
                            .font(.caption).foregroundStyle(Renk.ikincil)
                    }
                }
                .swipeActions {
                    Button("Sil", role: .destructive) { silinecek = s }
                }
            }
        }
        .kpZemin()
        .navigationTitle("Sezon arşivi")
        .task {
            await depo.sezonlariYukle()
            yukleniyor = false
        }
        .safeAreaInset(edge: .bottom) {
            if !depo.sezonlar.isEmpty {
                Text("Görüntülemek için dokun, silmek için sola kaydır.").font(.footnote).foregroundStyle(Renk.ikincil).padding(8)
            }
        }
        .confirmationDialog("\"\(silinecek?.ad ?? "")\" arşivi silinsin mi?", isPresented: Binding(get: { silinecek != nil }, set: { if !$0 { silinecek = nil } }),
                            titleVisibility: .visible) {
            Button("Arşivi sil", role: .destructive) {
                guard let s = silinecek else { return }
                Task { do { try await depo.sezonSil(s.id); gezinti.bildir("Sezon arşivi silindi") } catch { gezinti.goster(error) } }
            }
        } message: { Text("Bu işlem geri alınamaz.") }
    }
}

struct YeniSezonEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    var kapatUst: () -> Void
    @State private var ad = ""
    @State private var onay = false
    @State private var calisiyor = false

    var body: some View {
        let v = depo.veri
        Form {
            Section {
                TextField("Sezon adı (örn. 2027 Sezonu)", text: $ad)
            }
            Section("Ne olacak?") {
                Label("\(v.kumesler.count) kümes ve hayvan sayıları korunur", systemImage: "house.fill")
                Label("\(v.uniteler.count) civciv ünitesi korunur", systemImage: "shippingbox.fill")
                Label("\(v.aktifKuluckalar.count) aktif kuluçka korunur", systemImage: "oval.portrait.fill")
                Label("\(v.satislar.count) satış ve \(v.giderler.count) gider arşive alınıp silinir", systemImage: "archivebox.fill")
                    .foregroundStyle(Renk.turuncuYazi)
                Label("\(v.biten.count) tamamlanmış kuluçka silinir", systemImage: "trash").foregroundStyle(Renk.turuncuYazi)
            }
            Section {
                Button {
                    if ad.trimmingCharacters(in: .whitespaces).isEmpty { gezinti.goster(KuralHatasi("Sezon adı girin!\n(örn. 2027 Sezonu)")) }
                    else { onay = true }
                } label: {
                    HStack {
                        Spacer()
                        if calisiyor { ProgressView() } else { Text("Yeni sezonu başlat").bold() }
                        Spacer()
                    }
                }
                .disabled(calisiyor)
            }
        }
        .kpZemin()
        .navigationTitle("Yeni sezon")
        .confirmationDialog("\"\(ad)\" sezonu başlatılsın mı?", isPresented: $onay, titleVisibility: .visible) {
            Button("Sezonu başlat", role: .destructive) {
                calisiyor = true
                Task {
                    do {
                        try await depo.yeniSezon(ad: ad.trimmingCharacters(in: .whitespaces))
                        kapatUst(); gezinti.sekme = .ozet; gezinti.bildir("\"\(ad)\" sezonu başlatıldı")
                    } catch { gezinti.goster(error) }
                    calisiyor = false
                }
            }
        } message: { Text("Mevcut tüm veriler arşive alınacak. Satış, gider ve tamamlanmış kuluçkalar silinecek.") }
    }
}

struct YilSonuEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    var kapatUst: () -> Void
    @State private var alacak = true
    @State private var borc = true
    @State private var kulucka = false
    @State private var onay = false
    @State private var calisiyor = false

    var body: some View {
        let v = depo.veri
        let o = v.finansOzeti()
        Form {
            Section("Mevcut durum") {
                LabeledContent("Satış / gider", value: "\(v.satislar.count) / \(v.giderler.count)")
                LabeledContent("Ödenmemiş alacak", value: para(o.alacak))
                LabeledContent("Ödenmemiş borç", value: para(o.borc))
            }
            Section {
                Toggle("Ödenmemiş alacakları devret", isOn: $alacak)
                Toggle("Ödenmemiş borçları devret", isOn: $borc)
                Toggle("Tamamlanmış kuluçkaları sil", isOn: $kulucka)
            } footer: {
                Text("Tüm satış ve gider kayıtları silinir; işaretliyse ödenmemişler yeni döneme tek kayıt olarak aktarılır. Önce otomatik arşiv alınır.")
            }
            Section {
                Button { onay = true } label: {
                    HStack {
                        Spacer()
                        if calisiyor { ProgressView() } else { Text("Yeni döneme geç").bold() }
                        Spacer()
                    }
                }
                .disabled(calisiyor)
            }
        }
        .kpZemin()
        .navigationTitle("Yıl sonu")
        .confirmationDialog("Yeni döneme geçilsin mi?", isPresented: $onay, titleVisibility: .visible) {
            Button("Devam et", role: .destructive) {
                calisiyor = true
                Task {
                    do {
                        let m = try await depo.yilSonu(alacakDevret: alacak, borcDevret: borc, bitenKuluckalariSil: kulucka)
                        kapatUst(); gezinti.sekme = .ozet
                        gezinti.mesaj = Mesaj(baslik: "Yeni dönem hazır", metin: m)
                    } catch { gezinti.goster(error) }
                    calisiyor = false
                }
            }
        } message: { Text("Tüm satış ve gider kayıtları silinecek. Mevcut durum önce sezon arşivine kaydedilir.") }
    }
}

// MARK: - Hesap silme (App Store 5.1.1(v))

struct HesapSilEkrani: View {
    @Environment(Oturum.self) private var oturum
    @Environment(Gezinti.self) private var gezinti
    @State private var yazi = ""
    @State private var calisiyor = false

    var body: some View {
        Form {
            Section {
                Label("Hesabın ve tüm verilerin kalıcı olarak silinir: kümesler, kuluçkalar, üniteler, satışlar, giderler ve sezon arşivleri.",
                      systemImage: "exclamationmark.octagon.fill")
                    .foregroundStyle(Renk.kirmizi)
                Text("Bu işlem geri alınamaz. Gerekirse önce JSON yedek al.").font(.subheadline)
            }
            Section {
                TextField("Onay için SİL yaz", text: $yazi)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button(role: .destructive) {
                    calisiyor = true
                    Task {
                        do { try await oturum.hesabiSil() } catch { gezinti.goster(error) }
                        calisiyor = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        if calisiyor { ProgressView() } else { Text("Hesabımı kalıcı olarak sil").bold() }
                        Spacer()
                    }
                }
                .disabled(yazi.trimmingCharacters(in: .whitespaces).uppercased(with: Locale(identifier: "tr_TR")) != "SİL" || calisiyor)
            }
        }
        .kpZemin()
        .navigationTitle("Hesabımı sil")
    }
}
