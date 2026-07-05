// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Ruffnova",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    targets: [
        .target(
            name: "CRuffleFFI",
            path: "CRuffleFFI",
            sources: ["dummy.c", "ruffle_ffi.h"],
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedLibrary("ruffle_ffi"),
                .unsafeFlags(["-L", "CRuffleFFI/macos"], .when(platforms: [.macOS])),
                .unsafeFlags(["-L", "CRuffleFFI/ios"], .when(platforms: [.iOS])),
            ]
        ),
        .executableTarget(
            name: "Ruffnova",
            dependencies: ["CRuffleFFI"],
            path: ".",
            exclude: [
                "RuffleBridgingHeader.h",
                "Info.plist",
                "Info-iOS.plist",
                "Ruffnova.entitlements",
                "Ruffnova.xcodeproj",
                ".git",
                ".gitignore",
                ".swiftpm",
                ".DS_Store",
                "engine",
                "swfs",
                "Tests",
                "docs",
                "CRuffleFFI",
                "README.md",
                "LICENSE",
                "LICENSE-MIT",
                "LICENSE-APACHE",
                "RELEASE_AUDIT.md",
                "AGENT.md",
                "build_app.sh",
                "build_engine.sh",
                "setup.sh",
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Resources"),
            ],
            swiftSettings: [
                .define("RUST_FFI_AVAILABLE"),
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AudioUnit", .when(platforms: [.macOS])),
                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("SystemConfiguration", .when(platforms: [.macOS])),
                .linkedFramework("IOKit", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
            ]
        ),
        .testTarget(
            name: "RuffnovaTests",
            dependencies: ["Ruffnova"],
            path: "Tests/RuffnovaTests"
        ),
    ]
)
