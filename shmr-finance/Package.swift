// swift-tools-version: 6.2
import PackageDescription

// Весь код приложения собран в один модуль. Снаружи, в Xcode-проекте,
// остаётся только точка входа и ресурсы — SwiftPM не умеет описывать
// само iOS-приложение, лишь библиотеки.
let package = Package(
    name: "shmr-finance",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "AppFeature",
            targets: ["AppFeature"]
        )
    ],
    dependencies: [
        // Правило версии то же, что стоит в Xcode: иначе SwiftPM не сможет
        // выбрать версию, устраивающую оба объявления.
        .package(url: "https://github.com/airbnb/lottie-ios", from: "4.6.1"),
        // Диаграмма из блока 2 — код аналитики без неё не соберётся.
        .package(path: "Utilities")
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "PieChart", package: "Utilities")
            ],
            swiftSettings: [
                // Те же настройки, что у Xcode-таргета. Без изоляции по
                // умолчанию код не соберётся: он рассчитан на то, что
                // всё выполняется на главном потоке.
                .swiftLanguageMode(.v5),
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
