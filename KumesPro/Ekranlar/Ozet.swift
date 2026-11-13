import SwiftUI
import KumesCekirdek

struct OzetEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(Oturum.self) private var oturum
    @Environment(\.dynamicTypeSize) private var yaziBoyutu

    var body: some View {
        let v = depo.veri
        let ay = String(Gun.bugun.prefix(7))
        let fin = v.finansOzeti(ay: ay)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 14) {
                    HStack {
                        Button { gezinti.ac(.ayarlar) } label: {
                            Image(systemName: "line.3.horizontal").frame(width: 44, height: 44)
                        }.accessibilityLabel("Menü ve ayarlar")
                        Spacer(minLength: 4)
                        Image("Logo").resizable().scaledToFit().frame(width: 54, height: 54).accessibilityHidden(true)
                        (Text("Kümes").foregroundStyle(.white) + Text("Pro").foregroundStyle(Renk.altin))
                            .font(.title2.weight(.heavy))
                        Spacer(minLength: 4)
                        Button { gezinti.ac(.ayarlar) } label: {
                            Image(systemName: "bell").frame(width: 44, height: 44)
                        }.accessibilityLabel("Bildirim ayarları")
                    }
                    .foregroundStyle(.white)
                    HStack(spacing: 12) {
                        Image(systemName: "house.and.flag.fill")
                            .font(.title).foregroundStyle(Renk.altin).frame(width: 52, height: 52)
                            .background(.white.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hoş geldiniz,").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                            Text(oturum.adSoyad).font(.title2.weight(.bold)).foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                             count: yaziBoyutu.isAccessibilitySize ? 2 : 3), spacing: 8) {
                        ForEach([HayvanTuru.tavuk, .guvercin, .hindi, .kaz, .bildircin, .keklik]) { tur in
                            Button { gezinti.uniteBolumu = false; gezinti.sekme = .kumesler } label: {
                                HStack(spacing: 6) {
                                    Image("Tur-" + tur.rawValue).resizable().scaledToFit()
                                        .frame(width: 34, height: 42).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(tur == .kaz ? "Kaz/Ördek" : tur.ad).font(.caption).lineLimit(1)
                                        Text("\(v.kumesler.filter { $0.tur == tur.rawValue }.reduce(0) { $0 + $1.toplam })")
                                            .font(.title3.weight(.bold).monospacedDigit())
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(8).frame(maxWidth: .infinity, minHeight: 60)
                                .background(Renk.kart, in: RoundedRectangle(cornerRadius: 15))
                            }.buttonStyle(.plain).foregroundStyle(Renk.metin)
                        }
                    }
                }
                .padding(16)
                .background(LinearGradient(colors: [Renk.baslikYesil, Renk.yesilDolgu], startPoint: .top, endPoint: .bottom))

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        anaKart("Kümesler", "\(v.kumesler.count)", "house") { gezinti.sekme = .kumesler }
                        anaKart("Kuluçka", "\(v.aktifKuluckalar.count) aktif", "oval.portrait") {
                            gezinti.kayitBolumu = 0; gezinti.sekme = .kulucka
                        }
                        anaKart("Satışlar", "Bu ay: \(fin.satisSayisi)", "cart") {
                            gezinti.kayitBolumu = 1; gezinti.sekme = .kulucka
                        }
                    }
                    Text("Hızlı İşlemler").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                             count: yaziBoyutu.isAccessibilitySize ? 2 : 4), spacing: 8) {
                        hizli("Hayvan Ekle", "bird.fill") {
                            if v.kumesler.count == 1, let k = v.kumesler.first { gezinti.ac(.hayvan(kumesId: k.id, islem: .ekle)) }
                            else { gezinti.uniteBolumu = false; gezinti.sekme = .kumesler; gezinti.bildir("Hayvan eklemek için bir kümes seç") }
                        }
                        hizli("Satış Ekle", "cart.badge.plus") { gezinti.ac(.satis(nil)) }
                        hizli("Gider Ekle", "creditcard") { gezinti.ac(.gider(nil)) }
                        hizli("Kuluçka Başlat", "oval.portrait.fill") { gezinti.ac(.kulucka(nil)) }
                    }
                    Kart {
                        VStack(spacing: 10) {
                            Button { gezinti.sekme = .finans } label: {
                                HStack {
                                    Image(systemName: "chart.bar.fill").foregroundStyle(Renk.yesil)
                                    Text("Genel Durum").font(.title3.weight(.bold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }.buttonStyle(.plain)
                            durum("Toplam Hayvan", "\(v.toplamHayvan)", "bird.fill")
                            durum("Kuluçkadaki Yumurta", "\(v.aktifKuluckalar.reduce(0) { $0 + $1.yumurta })", "oval.portrait.fill")
                            durum("Bu Ay Gelir", para(fin.gelir), "banknote")
                            durum("Bu Ay Gider", para(fin.gider), "creditcard")
                        }
                    }
                    if !v.uniteler.isEmpty {
                        Button { gezinti.uniteBolumu = true; gezinti.sekme = .kumesler } label: {
                            Kart {
                                HStack {
                                    Image(systemName: "shippingbox.fill")
                                    Text("\(v.toplamCivciv) civciv · \(v.toplamYavruGuvercin) yavru güvercin")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    ForEach(v.kuluckaUyarilari().filter { $0.gecikme > 0 }) { u in
                        Button { gezinti.ac(.cikim(u.kuluckaId)) } label: {
                            UyariSatiri(simge: "alarm.fill", renk: Renk.kirmiziDolgu, baslik: u.baslik, metin: "Çıkım sonucunu girmek için dokun")
                        }.buttonStyle(.plain)
                    }
                    if let k = v.siradakiKulucka() { SiradakiKart(k: k) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Renk.zemin)
        .refreshable { await depo.yukle() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func anaKart(_ ad: String, _ deger: String, _ simge: String, eylem: @escaping () -> Void) -> some View {
        Button(action: eylem) {
            VStack(spacing: 5) {
                Image(systemName: simge).font(.title).foregroundStyle(Renk.altin)
                Text(ad).font(.subheadline.weight(.semibold))
                Text(deger).font(.caption)
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 100)
            .background(Renk.baslikYesil, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }

    private func hizli(_ ad: String, _ simge: String, eylem: @escaping () -> Void) -> some View {
        Button(action: eylem) {
            VStack(spacing: 8) {
                Image(systemName: simge).font(.title2).foregroundStyle(Renk.yesil)
                Text(ad).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            }
            .foregroundStyle(Renk.metin).frame(maxWidth: .infinity, minHeight: 86)
            .background(Renk.kart, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).disabled(depo.saltOkunur)
    }

    private func durum(_ ad: String, _ deger: String, _ simge: String) -> some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Image(systemName: simge).foregroundStyle(Renk.yesil).frame(width: 24)
                Text(ad).font(.subheadline)
                Spacer()
                Text(deger).font(.headline.monospacedDigit())
            }
        }
    }
}


/// Son satış/gider karışık listesi.
struct OzetHareket: Identifiable {
    let id: String
    let tarih: String
    var satis: Satis?
    var gider: Gider?

    static func son(_ v: Veri) -> [OzetHareket] {
        let s = v.satislar.prefix(3).map { OzetHareket(id: "s" + $0.id, tarih: $0.tarih, satis: $0) }
        let g = v.giderler.prefix(3).map { OzetHareket(id: "g" + $0.id, tarih: $0.tarih, gider: $0) }
        return Array((s + g).sorted { $0.tarih > $1.tarih }.prefix(4))
    }
}

struct UyariSatiri: View {
    let simge: String
    let renk: Color
    let baslik: String
    let metin: String?

    var body: some View {
        HStack(spacing: 12) {
            IkonRozeti(simge: simge, renk: .white, zemin: renk)
            VStack(alignment: .leading, spacing: 1) {
                Text(baslik).font(.subheadline.weight(.bold)).foregroundStyle(Renk.metin)
                if let metin { Text(metin).font(.caption).foregroundStyle(Renk.ikincil) }
            }
            Spacer()
            if metin != nil { Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Renk.ikincil) }
        }
        .padding(12)
        .background(Renk.kart, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

struct SayiKarti: View {
    let simge: String
    let renk: Color
    let zemin: Color
    var resim: String? = nil
    let deger: String
    let alt: String
    var degerRenk: Color = Renk.metin
    var eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            Kart(dolgu: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    if let resim {
                        Image(resim).resizable().scaledToFill().frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).accessibilityHidden(true)
                    } else {
                        IkonRozeti(simge: simge, renk: renk, zemin: zemin)
                    }
                    Text(deger).font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(degerRenk)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(alt).font(.caption).foregroundStyle(Renk.ikincil).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct HareketSatiri: View {
    let simge: String
    let renk: Color
    let zemin: Color
    let baslik: String
    let alt: String
    let tutar: String
    let tutarRenk: Color
    var etiket: String?

    var body: some View {
        HStack(spacing: 12) {
            IkonRozeti(simge: simge, renk: renk, zemin: zemin)
            VStack(alignment: .leading, spacing: 1) {
                Text(baslik).font(.subheadline.weight(.bold)).foregroundStyle(Renk.metin).lineLimit(1)
                Text(alt).font(.caption).foregroundStyle(Renk.ikincil).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(tutar).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(tutarRenk)
                if let etiket { Hap(yazi: etiket) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

/// Sıradaki çıkım kartı (turuncu, halka sayaçlı).
struct SiradakiKart: View {
    @Environment(Gezinti.self) private var gezinti
    let k: Kulucka

    var body: some View {
        let d = k.durum()
        Button {
            if d.gecikti { gezinti.ac(.cikim(k.id)) } else { gezinti.sekme = .kulucka }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Renk.kart)
                    Halka(oran: Double(d.gecen) / Double(max(1, k.sure)), renk: d.gecikti ? Renk.kirmiziDolgu : Renk.turuncuParlak,
                          iz: Renk.turuncuIz, kalinlik: 8)
                    VStack(spacing: 0) {
                        Text("\(d.gecikti ? d.gecikme : d.kalan)").font(.title3.weight(.bold).monospacedDigit())
                        Text(d.gecikti ? "gün geç" : "gün").font(.system(size: 10, weight: .semibold)).foregroundStyle(Renk.ikincil)
                    }
                }
                .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SIRADAKİ ÇIKIM").font(.caption.weight(.bold)).foregroundStyle(Renk.turuncuYazi).tracking(0.5)
                    Text(k.ad).font(.headline).foregroundStyle(Renk.metin).lineLimit(1)
                    if let c = d.cikim, let s = d.sepet {
                        Text("Sepete \(Gun.kisa(s)) · Çıkım \(Gun.kisa(c))").font(.subheadline).foregroundStyle(Renk.metin.opacity(0.8))
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(Renk.turuncuAcik, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
