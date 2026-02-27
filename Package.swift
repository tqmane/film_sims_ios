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
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "FilmSims",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
            ],
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
                .copy("Resources/GoogleService-Info.plist"),
                .copy("Resources/luts"),
                .copy("Resources/watermark"),
            ]
        ),
    ]
)
