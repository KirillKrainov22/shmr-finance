// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Utilities",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        // По ТЗ библиотека статическая.
        .library(
            name: "PieChart",
            type: .static,
            targets: ["PieChart"]
        )
    ],
    targets: [
        .target(
            name: "PieChart",
            // Тот же режим языка, что и у приложения, иначе строгая проверка
            // изоляции из Swift 6 разошлась бы с остальным кодом.
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
