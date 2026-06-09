// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MarkMark",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "MarkMark",
            targets: ["MarkMark"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-markdown.git",
            from: "0.5.0"
        )
    ],
    targets: [
        // Shared library — rendering logic, theme, localization
        .target(
            name: "MarkdownReaderKit",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/MarkdownReaderKit"
        ),
        // Main application（可执行文件名 = MarkMark；源码目录 Sources/MarkMark）
        .executableTarget(
            name: "MarkMark",
            dependencies: [
                "MarkdownReaderKit",
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/MarkMark",
            resources: [
                .process("Assets.xcassets"),
                .copy("Resources")
            ]
        ),
        // Quick Look Preview Extension
        // Built as a regular target (not executable) — the executable entry point
        // (NSExtensionMain) is provided by a C wrapper in build-app.sh at link time.
        // SPM's executableTarget always generates _main, which is wrong for App Extensions.
        .target(
            name: "MarkdownReaderQL",
            dependencies: [
                "MarkdownReaderKit"
            ],
            path: "Sources/MarkdownReaderQL"
        ),
        // Unit tests for the shared logic library (CriticMarkup, HTML rendering)
        .testTarget(
            name: "MarkdownReaderKitTests",
            dependencies: [
                "MarkdownReaderKit"
            ],
            path: "Tests/MarkdownReaderKitTests"
        )
    ]
)
