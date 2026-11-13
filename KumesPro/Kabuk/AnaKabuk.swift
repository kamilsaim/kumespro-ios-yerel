import SwiftUI
import KumesCekirdek

/// Sekmeler + özel alt çubuk (ortada turuncu + düğmesi) + tüm alt pencereler.
/// Sistem sekme çubuğu gizli; TabView sekme durumlarını korur (Türbedar/Sinerji düzeni).
struct AnaKabuk: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(Oturum.self) private var oturum

    var body: some View {
        @Bindable var g = gezinti
        VStack(spacing: 0) {
            if let a = depo.arsiv { ArsivSeridi(sezon: a) }
            TabView(selection: $g.sekme) {
                NavigationStack { OzetEkrani() }.tag(Sekme.ozet).toolbar(.hidden, for: .tabBar)
                NavigationStack { KumeslerEkrani() }.tag(Sekme.kumesler).toolbar(.hidden, for: .tabBar)
                NavigationStack { KayitlarEkrani() }.tag(Sekme.kulucka).toolbar(.hidden, for: .tabBar)
                NavigationStack { RaporlarEkrani() }.tag(Sekme.finans).toolbar(.hidden, for: .tabBar)
            }
            AltCubuk(secili: $g.sekme)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(Renk.zemin)
        .overlay(alignment: .top) {
            if let s = gezinti.serit {
                Text(s)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Renk.maviKoyu, in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.spring(duration: 0.35), value: gezinti.serit)
        .sheet(item: $g.pencere) { p in PencereIcerigi(pencere: p) }
        .alert(gezinti.mesaj?.baslik ?? "", isPresented: Binding(get: { gezinti.mesaj != nil }, set: { if !$0 { gezinti.mesaj = nil } }),
               presenting: gezinti.mesaj) { _ in
            Button("Tamam", role: .cancel) {}
        } message: { m in
            if let t = m.metin { Text(t) }
        }
        .overlay {
            if !depo.yuklendi {
                if let h = depo.hata {
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark").font(.system(size: 40)).foregroundStyle(Renk.mavi)
                        Text(h).multilineTextAlignment(.center).foregroundStyle(Renk.metin)
                        Button("Tekrar dene") { Task { await depo.yukle() } }.buttonStyle(.borderedProminent)
                        Button("Çıkış yap") { Task { await oturum.cikis() } }.font(.footnote)
                    }
                    .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(Renk.zemin)
                } else {
                    ProgressView("Yükleniyor…").frame(maxWidth: .infinity, maxHeight: .infinity).background(Renk.zemin)
                }
            }
        }
        .onChange(of: depo.yuklendi) { bekleyeniIsle() }
        .onChange(of: gezinti.bekleyenPencere) { bekleyeniIsle() }
        .onChange(of: gezinti.bekleyenSekme) { bekleyeniIsle() }
        .onAppear { bekleyeniIsle() }
    }

    /// İkon menüsü / bildirim soğuk açılışta veri yüklenmeden gelirse beklenir.
    private func bekleyeniIsle() {
        guard depo.yuklendi else { return }
        if let s = gezinti.bekleyenSekme { gezinti.bekleyenSekme = nil; gezinti.sekme = s }
        if let p = gezinti.bekleyenPencere, !depo.saltOkunur { gezinti.bekleyenPencere = nil; gezinti.ac(p) }
    }
}

struct ArsivSeridi: View {
    @Environment(Depo.self) private var depo
    let sezon: Sezon

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "archivebox.fill")
            VStack(alignment: .leading, spacing: 0) {
                Text("Arşiv: \(sezon.ad)").font(.subheadline.weight(.bold)).lineLimit(1)
                Text(Gun.goster(sezon.tarih) + " · yalnız görüntüleme").font(.caption)
            }
            Spacer()
            Button("Çık") { Task { await depo.canliyaDon() } }
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.white.opacity(0.25), in: Capsule())
                .foregroundStyle(.white)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Renk.baslikYesil)
    }
}

/// Özel alt çubuk: dört sekme, ortada yükseltilmiş + düğmesi.
struct AltCubuk: View {
    @Binding var secili: Sekme

    var body: some View {
        HStack(spacing: 0) {
            dugme(.ozet, "Ana Sayfa", "house")
            dugme(.kumesler, "Kümesler", "square.grid.2x2")
            dugme(.kulucka, "Kayıtlar", "list.bullet.rectangle")
            dugme(.finans, "Raporlar", "chart.bar")
        }
        .padding(.vertical, 8)
        .background(Renk.kart.ignoresSafeArea(edges: .bottom))
    }

    private func dugme(_ s: Sekme, _ ad: String, _ simge: String) -> some View {
        let acik = secili == s
        return Button {
            if !acik { Titresim.dokun() }
            secili = s
        } label: {
            VStack(spacing: 4) {
                Image(systemName: simge).font(.title3)
                Text(ad).font(.caption.weight(.semibold))
            }
            .foregroundStyle(acik ? .white : Renk.metin)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.vertical, 4)
            .background(acik ? Renk.baslikYesil : .clear, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(acik ? .isSelected : [])
    }
}

/// `+` menüsü.
struct EkleMenusu: View {
    @Environment(Gezinti.self) private var gezinti
    @Environment(Depo.self) private var depo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ne eklemek istersin?").font(.title3.weight(.bold)).padding(.horizontal, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                secim("Satış", "tag.fill", Renk.mavi, Renk.maviAcik, .satis(nil))
                secim("Gider", "creditcard.fill", Renk.kirmiziDolgu, Renk.kirmiziAcik, .gider(nil))
                secim("Kuluçka başlat", "oval.portrait.fill", Renk.turuncu, Renk.turuncuAcik, .kulucka(nil))
                secim("Hayvan giriş/çıkış", "arrow.up.arrow.down", Renk.yesilDolgu, Renk.yesilAcik,
                      depo.veri.kumesler.count == 1 ? .hayvan(kumesId: depo.veri.kumesler[0].id, islem: .ekle) : nil)
                secim("Yeni kümes", "house.fill", Renk.kahve, Renk.kahveAcik, .kumes(nil))
                secim("Civciv ünitesi", "shippingbox.fill", Renk.camgobegi, Renk.camgobegiAcik, .yeniUnite)
            }
        }
        .padding(20)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private func secim(_ ad: String, _ simge: String, _ renk: Color, _ zemin: Color, _ p: Pencere?) -> some View {
        Button {
            if let p { gezinti.ac(p) } else {
                // birden çok kümes: kümes seçimi Kümesler sekmesinde
                gezinti.pencere = nil
                gezinti.uniteBolumu = false
                gezinti.sekme = .kumesler
                gezinti.bildir("Hayvan eklemek için bir kümes seç")
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: simge).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 52, height: 52).background(renk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(ad).font(.footnote.weight(.bold)).foregroundStyle(Renk.metin)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(zemin, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Kökten açılan pencerenin içeriği.
struct PencereIcerigi: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(Oturum.self) private var oturum
    let pencere: Pencere

    var body: some View {
        icerik
            .environment(depo).environment(gezinti).environment(oturum)
    }

    @ViewBuilder private var icerik: some View {
        switch pencere {
        case .ekleMenusu: EkleMenusu()
        case .satis(let id): SatisFormu(satisId: id)
        case .gider(let id): GiderFormu(giderId: id)
        case .kulucka(let id): KuluckaFormu(kuluckaId: id)
        case .cikim(let id): CikimFormu(kuluckaId: id)
        case .kumes(let id): KumesFormu(kumesId: id)
        case .hayvan(let k, let i): HayvanFormu(kumesId: k, islem: i)
        case .yeniUnite: UniteFormu(uniteId: nil)
        case .uniteDuzenle(let id): UniteFormu(uniteId: id)
        case .partiEkle(let u): PartiEkleFormu(uniteId: u)
        case .partiCikar(let u, let p): PartiCikarFormu(uniteId: u, partiId: p)
        case .partiDuzenle(let u, let p): PartiDuzenleFormu(uniteId: u, partiId: p)
        case .aktar(let u, let p): AktarFormu(uniteId: u, partiId: p)
        case .alacaklar: AlacakListesi()
        case .borclar: BorcListesi()
        case .ayarlar: AyarlarEkrani()
        }
    }
}
