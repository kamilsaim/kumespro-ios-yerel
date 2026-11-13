import SwiftUI
import Charts
import KumesCekirdek

struct KayitlarEkrani: View {
    @Environment(Gezinti.self) private var gezinti

    var body: some View {
        @Bindable var g = gezinti
        VStack(spacing: 0) {
            Picker("Kayıt türü", selection: $g.kayitBolumu) {
                Text("Kuluçka").tag(0)
                Text("Satışlar").tag(1)
                Text("Giderler").tag(2)
            }
            .pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 8)
            if g.kayitBolumu == 0 {
                KuluckaEkrani()
            } else {
                FinansEkrani(ilkFiltre: g.kayitBolumu == 1 ? .satislar : .giderler)
                    .id(g.kayitBolumu)
            }
        }
    }
}

struct RaporlarEkrani: View {
    @Environment(Depo.self) private var depo
    @Environment(Gezinti.self) private var gezinti
    @State private var ay: String? = String(Gun.bugun.prefix(7))

    var body: some View {
        let v = depo.veri
        let fin = v.finansOzeti(ay: ay)
        List {
            Section("Finansal Durum") {
                LabeledContent("Gelir", value: para(fin.gelir))
                LabeledContent("Gider", value: para(fin.gider))
                LabeledContent("Net", value: para(fin.net))
                Button { gezinti.ac(.alacaklar) } label: {
                    LabeledContent("Alacaklar", value: para(fin.alacak))
                }
                Button { gezinti.ac(.borclar) } label: {
                    LabeledContent("Borçlar", value: para(fin.borc))
                }
            }
            Section("Hayvan Dağılımı") {
                if v.toplamHayvan == 0 { Text("Henüz hayvan kaydı yok.").foregroundStyle(.secondary) }
                Chart {
                    ForEach(HayvanTuru.allCases) { tur in
                        let adet = v.kumesler.filter { $0.tur == tur.rawValue }.reduce(0) { $0 + $1.toplam }
                        if adet > 0 {
                            BarMark(x: .value("Adet", adet), y: .value("Tür", tur.ad))
                                .foregroundStyle(Renk.yesil)
                                .annotation(position: .trailing) { Text("\(adet)").font(.caption) }
                        }
                    }
                }
                .frame(height: 220)
                .accessibilityLabel("Türlere göre hayvan sayıları")
            }
            Section("Kuluçka Verimi") {
                let biten = v.biten
                let yumurta = biten.reduce(0) { $0 + $1.yumurta }
                let civciv = biten.reduce(0) { $0 + ($1.cikim?.civciv ?? 0) }
                LabeledContent("Tamamlanan kuluçka", value: "\(biten.count)")
                LabeledContent("Çıkan civciv", value: "\(civciv)")
                LabeledContent("Çıkım oranı", value: yumurta > 0 ? "%\(Int(Double(civciv) / Double(yumurta) * 100))" : "—")
            }
        }
        .kpZemin()
        .navigationTitle("Raporlar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Dönem", selection: $ay) {
                        Text("Tüm dönemler").tag(String?.none)
                        ForEach(Array(Set(v.aylar + [String(Gun.bugun.prefix(7))])).sorted(by: >), id: \.self) { a in
                            Text(a).tag(String?.some(a))
                        }
                    }
                } label: { Image(systemName: "calendar") }
                .accessibilityLabel("Rapor dönemi")
            }
        }
        .refreshable { await depo.yukle() }
    }
}
