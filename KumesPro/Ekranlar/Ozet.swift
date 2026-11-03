import SwiftUI
import KumesCekirdek

struct OzetEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @Environment(Oturum.self) private var oturum

    var body: some View {
        let v = depo.veri
        let fin = v.finansOzeti()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ust(v)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 16) {
                    let uyarilar = v.kuluckaUyarilari()
                    ForEach(uyarilar.filter { $0.gecikme > 0 }) { u in
                        Button { gezinti.ac(.cikim(u.kuluckaId)) } label: {
                            UyariSatiri(simge: "alarm.fill", renk: Renk.kirmiziDolgu, baslik: u.baslik,
                                        metin: "Çıkım sonucunu girmek için dokun")
                        }.buttonStyle(.plain)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        SayiKarti(simge: "bird.fill", renk: Renk.mavi, zemin: Renk.maviAcik, deger: "\(v.toplamHayvan)",
                                  alt: "hayvan · \(v.toplamErkek) E · \(v.toplamDisi) D") { gezinti.sekme = .kumesler }
                        SayiKarti(simge: "oval.portrait.fill", renk: Renk.turuncuYazi, zemin: Renk.turuncuAcik,
                                  deger: "\(v.aktifKuluckalar.count)",
                                  alt: "kuluçka · \(v.aktifKuluckalar.reduce(0) { $0 + $1.yumurta }) yumurta") { gezinti.sekme = .kulucka }
                        SayiKarti(simge: "chart.line.uptrend.xyaxis", renk: Renk.yesil, zemin: Renk.yesilAcik,
                                  deger: para(fin.net), alt: fin.net >= 0 ? "net kâr" : "net zarar", degerRenk: fin.net >= 0 ? Renk.yesil : Renk.kirmizi) {
                            gezinti.sekme = .finans
                        }
                        SayiKarti(simge: "arrow.down.left", renk: Renk.turuncuYazi, zemin: Renk.turuncuAcik,
                                  deger: para(fin.alacak), alt: fin.alacak > 0 ? "alacak · \(fin.alacakKisi) kişi" : "bekleyen alacak yok",
                                  degerRenk: Renk.turuncuYazi) { gezinti.ac(.alacaklar) }
                    }

                    if v.toplamCivciv + v.toplamYavruGuvercin > 0 {
                        Button { gezinti.uniteBolumu = true; gezinti.sekme = .kumesler } label: {
                            Kart(dolgu: 14) {
                                HStack(spacing: 12) {
                                    IkonRozeti(simge: "shippingbox.fill", renk: Renk.camgobegi, zemin: Renk.camgobegiAcik)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(v.toplamCivciv) civciv").font(.headline)
                                        if v.toplamYavruGuvercin > 0 {
                                            Text("+ \(v.toplamYavruGuvercin) yavru güvercin").font(.caption).foregroundStyle(Renk.ikincil)
                                        } else {
                                            Text("\(v.uniteler.count) ünitede").font(.caption).foregroundStyle(Renk.ikincil)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Renk.ikincil)
                                }
                            }
                        }.buttonStyle(.plain)
                    }

                    if let k = v.siradakiKulucka() {
                        SiradakiKart(k: k)
                    }

                    ForEach(uyarilar.filter { $0.gecikme <= 0 && $0.kuluckaId != v.siradakiKulucka()?.id }) { u in
                        UyariSatiri(simge: "bell.fill", renk: Renk.turuncu, baslik: u.baslik, metin: nil)
                    }

                    sonHareketler(v)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(alignment: .top) {
            ZStack {
                Renk.maviKoyu
                Dalgalar()
            }
            .frame(height: 300)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous))
            .ignoresSafeArea(edges: .top)
        }
        .background(Renk.zemin)
        .refreshable { await depo.yukle() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func ust(_ v: Veri) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(selam(Calendar.current.component(.hour, from: Date()))) · \(Gun.uzun(Date()))")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                Text("KümesPro").font(.logo(32)).foregroundStyle(.white)
            }
            Spacer()
            Button { gezinti.ac(.ayarlar) } label: {
                Text(oturum.gorunum.harf)
                    .font(.headline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Renk.turuncuParlak, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
            .accessibilityLabel("Hesap ve ayarlar")
        }
        .padding(.top, 12)
    }

    @ViewBuilder private func sonHareketler(_ v: Veri) -> some View {
        let liste = OzetHareket.son(v)
        if !liste.isEmpty {
            Kart(dolgu: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Son hareketler").font(.headline)
                        Spacer()
                        Button("Tümü") { gezinti.sekme = .finans }.font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
                    ForEach(liste) { x in
                        Divider().padding(.leading, 64)
                        if let s = x.satis {
                            HareketSatiri(simge: "arrow.up", renk: Renk.yesil, zemin: Renk.yesilAcik, baslik: s.musteriAdi,
                                          alt: s.urunOzeti.isEmpty ? Gun.goster(s.tarih) : s.urunOzeti,
                                          tutar: "+" + para(s.toplam), tutarRenk: Renk.yesil,
                                          etiket: s.kalan > 0 ? para(s.kalan) + " kalan" : nil)
                        } else if let g = x.gider {
                            HareketSatiri(simge: "arrow.down", renk: Renk.kirmizi, zemin: Renk.kirmiziAcik, baslik: g.baslik,
                                          alt: v.kumes(g.kumesId)?.ad ?? g.turu.ad,
                                          tutar: "−" + para(g.tutar), tutarRenk: Renk.kirmizi,
                                          etiket: g.kalan > 0 ? para(g.kalan) + " borç" : nil)
                        }
                    }
                }
                .padding(.bottom, 6)
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
    let deger: String
    let alt: String
    var degerRenk: Color = Renk.metin
    var eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            Kart(dolgu: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    IkonRozeti(simge: simge, renk: renk, zemin: zemin)
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
