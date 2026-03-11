// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FilmSims",
    defaultLocalization: "en",
    platforms: [
        .iOS("16.4"),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "FilmSims",
            targets: ["FilmSims"]
        ),
        .library(
            name: "FilmSimsShareExtension",
            targets: ["FilmSimsShareExtension"]
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
                "FilmSimsShared",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
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
                .copy("SecureResources/luts"),
                .copy("SecureResources/watermark"),
            ]
        ),
        .target(
            name: "FilmSimsShared",
            path: "Sources/FilmSimsShared"
        ),
        .target(
            name: "FilmSimsShareExtension",
            dependencies: ["FilmSimsShared"],
            path: "Sources/FilmSimsShareExtension"
        ),
    ]
)
