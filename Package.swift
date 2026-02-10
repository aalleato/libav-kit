// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "libav-kit",
    platforms: [
        .macOS("14.4"),
    ],
    products: [
        .library(name: "LibAVKit", targets: ["LibAVKit"]),
    ],
    targets: [
        .systemLibrary(
            name: "CFFmpeg",
            path: "Sources/CFFmpeg",
            pkgConfig: "libavcodec libavformat libavutil libswresample",
            providers: [
                .brew(["ffmpeg"]),
            ]
        ),
        .target(
            name: "LibAVKit",
            dependencies: ["CFFmpeg"],
            path: "Sources/LibAVKit",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
            ]
        ),
        .testTarget(
            name: "LibAVKitTests",
            dependencies: ["LibAVKit"],
            path: "Tests/LibAVKitTests"
        ),
    ]
)
