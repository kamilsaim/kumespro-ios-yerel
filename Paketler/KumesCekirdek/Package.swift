// swift-tools-version: 5.10
// KümesPro çekirdeği: yalnız Foundation kullanan modeller ve iş kuralları (web app.html'in karşılığı).
// Linux CI'da `swift test` ile sınanır; iOS uygulaması ve widget bu paketi kullanır.
import PackageDescription

let package = Package(
    name: "KumesCekirdek",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KumesCekirdek", targets: ["KumesCekirdek"])
    ],
    targets: [
        .target(name: "KumesCekirdek"),
        .testTarget(name: "KumesCekirdekTests", dependencies: ["KumesCekirdek"])
    ]
)
