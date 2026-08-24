// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Yappie",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Parakeet TDT as CoreML on the Neural Engine. Optional at runtime — Apple's
        // SpeechTranscriber remains the default and needs no dependency at all.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.6")
    ],
    targets: [
        // The dictionary is its own target so it can be tested directly, and because its
        // behaviour is a cross-platform contract: the Windows app reimplements this logic in
        // C#, and both sides run the same vectors in shared/dictionary-test-vectors.json.
        .target(
            name: "YappieDictionary",
            path: "Sources/YappieDictionary",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Words-per-day, streaks, heatmap. Foundation-only so CI can run it on the
        // same runners that cannot compile the macOS 26 app target.
        .target(
            name: "YappieActivity",
            path: "Sources/YappieActivity",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "Yappie",
            dependencies: [
                "YappieDictionary",
                "YappieActivity",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/Yappie",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "YappieDictionaryTests",
            dependencies: ["YappieDictionary"],
            path: "Tests/YappieDictionaryTests",
            resources: [.copy("dictionary-test-vectors.json")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "YappieActivityTests",
            dependencies: ["YappieActivity"],
            path: "Tests/YappieActivityTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
