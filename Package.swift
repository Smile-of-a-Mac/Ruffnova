// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Ruffnova",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "CRuffleFFI",
            path: "CRuffleFFI",
            sources: ["dummy.c", "ruffle_ffi.h"],
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedLibrary("ruffle_ffi"),
                .unsafeFlags(["-L", "CRuffleFFI"]),
            ]
        ),
        .executableTarget(
            name: "Ruffnova",
            dependencies: ["CRuffleFFI"],
            path: "Ruffnova",
            exclude: ["RuffleBridgingHeader.h", "Info.plist", "Ruffnova.entitlements"],
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
                .linkedFramework("Cocoa"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AudioUnit"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
