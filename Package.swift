// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FilmSims",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "FilmSims",
            targets: ["FilmSims"]
        ),
    ],
    targets: [
        .target(
            name: "FilmSims",
            path: "Sources/FilmSims",
            resources: [
                // Use explicit rules to avoid SwiftPM flattening the LUT directory structure.
                .process("Resources/Assets.xcassets"),
                .process("Resources/en.lproj"),
                .process("Resources/ja.lproj"),
                .process("Resources/ko.lproj"),
                .process("Resources/zh-Hans.lproj"),
                .process("Resources/ar.lproj"),
                .process("Resources/de.lproj"),
                .process("Resources/es.lproj"),
                .process("Resources/fr.lproj"),
                .process("Resources/it.lproj"),
                .process("Resources/pt.lproj"),
                .process("Resources/ru.lproj"),
                .copy("Resources/film_grain.png"),
                .copy("Resources/film_grain_oneplus.png"),
                .copy("Resources/luts"),
                .copy("Resources/watermark"),
            ]
        ),
    ]
)
