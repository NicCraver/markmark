// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownReader",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "MarkdownReader",
            targets: ["MarkdownReader"]
        )
    ],
    dependencies: [
        .package(
            url: "git@github.com:gonzalezreal/textual.git",
            .upToNextMinor(from: "0.3.1")
        )
    ],
    targets: [
        .executableTarget(
            name: "MarkdownReader",
            dependencies: [
                .product(name: "Textual", package: "textual")
            ],
            path: "Sources/MarkdownReader",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
