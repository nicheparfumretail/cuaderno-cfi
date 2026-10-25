// swift-tools-version: 5.9
import PackageDescription

// CuadernoCore: el motor contable, Swift puro (solo Foundation).
// Sus tests corren en Linux con `swift test`. La app (CuadernoApp.swiftpm) lleva
// una copia de estas fuentes en `Core/` (ver scripts/sincronizar_core.py).
let package = Package(
    name: "CuadernoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CuadernoCore", targets: ["CuadernoCore"]),
    ],
    targets: [
        .target(name: "CuadernoCore"),
        .testTarget(name: "CuadernoCoreTests", dependencies: ["CuadernoCore"]),
    ]
)
