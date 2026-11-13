import AuthenticationServices
import SwiftUI
import KumesCekirdek

@main
struct KumesProApp: App {
    @UIApplicationDelegateAdaptor(UygulamaDelegesi.self) private var delege
    @State private var oturum = Oturum()
    @State private var depo = Depo()
    @State private var gezinti = Gezinti.ortak

    var body: some Scene {
        WindowGroup {
            KokEkran()
                .environment(oturum)
                .environment(depo)
                .environment(gezinti)
                .tint(Renk.mavi)
                .task { await oturum.baslat() }
        }
    }
}

/// Oturum durumuna göre: açılış → giriş → uygulama.
private struct KokEkran: View {
    @Environment(Oturum.self) private var oturum
    @Environment(Depo.self) private var depo
    @Environment(\.scenePhase) private var evre

    var body: some View {
        Group {
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--kp-arayuz-testi") {
                AnaKabuk()
                    .overlay(alignment: .top) { Text("ÖRNEK VERİ").font(.caption2).padding(4).background(.ultraThinMaterial) }
                    .task { depo.simulatorOrnegi() }
            } else {
                normalIcerik
            }
            #else
            normalIcerik
            #endif
        }
    }

    private var normalIcerik: some View {
        Group {
            if !oturum.hazir {
                AcilisEkrani()
            } else if oturum.kullanici == nil {
                GirisEkrani()
            } else {
                AnaKabuk()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: oturum.kullaniciId)
        .task(id: oturum.kullaniciId) { await depo.baslat(kullanici: oturum.kullaniciId) }
        .onChange(of: evre) { _, yeni in
            // Öne gelince tazele: başka cihazdaki (web/Android) değişiklikler gelsin, kalan günler ilerlesin
            if yeni == .active, oturum.kullaniciId != nil, !depo.saltOkunur { Task { await depo.yukle() } }
        }
    }
}

struct AcilisEkrani: View {
    var body: some View {
        ZStack {
            Color("Zemin").ignoresSafeArea()
            Image("Acilis").resizable().scaledToFit().frame(width: 160, height: 160)
        }
    }
}

// MARK: - Giriş

struct GirisEkrani: View {
    @Environment(Oturum.self) private var oturum
    @Environment(\.colorScheme) private var sema
    @State private var hata: String?
    @State private var bekliyor = false

    var body: some View {
        ZStack {
            Renk.maviKoyu.ignoresSafeArea()
            Dalgalar().ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                Image("Logo").resizable().scaledToFit().frame(width: 132, height: 132)
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 3))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .accessibilityHidden(true)
                Text("KümesPro").font(.logo(40)).foregroundStyle(.white).padding(.top, 20)
                Text("Kümes, kuluçka, satış ve gider takibi")
                    .font(.callout.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center).padding(.top, 6)
                Spacer()
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { istek in
                        oturum.appleIstegiHazirla(istek)
                    } onCompletion: { sonuc in
                        Task {
                            bekliyor = true
                            defer { bekliyor = false }
                            do { try await oturum.appleSonucu(sonuc) } catch { hata = error.localizedDescription }
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        Task {
                            bekliyor = true
                            defer { bekliyor = false }
                            do { try await oturum.googleIleGir() } catch { hata = error.localizedDescription }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("G").font(.system(size: 20, weight: .bold)).foregroundStyle(Renk.mavi)
                            Text("Google ile giriş yap").font(.system(size: 19, weight: .semibold))
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if bekliyor { ProgressView().tint(.white).padding(.top, 4) }
                    if let hata {
                        Text(hata).font(.footnote).foregroundStyle(.white)
                            .padding(10).frame(maxWidth: .infinity)
                            .background(Renk.kirmiziDolgu.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    }
                    Text("Web ve Android'deki hesabınla giriş yap; verilerin aynı kalır.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
                        .padding(.top, 4)
                    Link("Gizlilik politikası", destination: Sabitler.gizlilik)
                        .font(.footnote.weight(.semibold)).foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .disabled(bekliyor)
            }
        }
    }
}

/// Mavi başlık alanlarındaki organik şekiller (süs).
struct Dalgalar: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.64, y: 0))
                    p.addCurve(to: CGPoint(x: w, y: h * 0.18), control1: CGPoint(x: w * 0.7, y: h * 0.12),
                               control2: CGPoint(x: w * 0.85, y: h * 0.05))
                    p.addLine(to: CGPoint(x: w, y: 0)); p.closeSubpath()
                }.fill(Renk.maviOrta)
                Circle().fill(Renk.maviOrta.opacity(0.5)).frame(width: 160, height: 160)
                    .position(x: w * 0.92, y: min(h * 0.75, 200))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.78))
                    p.addCurve(to: CGPoint(x: w * 0.55, y: h), control1: CGPoint(x: w * 0.2, y: h * 0.7),
                               control2: CGPoint(x: w * 0.4, y: h * 0.85))
                    p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
                }.fill(Color.black.opacity(0.12))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
