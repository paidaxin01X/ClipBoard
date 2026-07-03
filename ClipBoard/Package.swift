// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipBoard",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "ClipBoardCore",
            path: "Sources/ClipBoardCore"
        ),
        .executableTarget(
            name: "ClipBoard",
            dependencies: ["ClipBoardCore"],
            path: "Sources/ClipBoard",
            exclude: ["Info.plist"]  // 打包脚本手动复制，SPM 不需要处理
        ),
        .executableTarget(
            name: "ClipBoardTests",
            dependencies: ["ClipBoardCore"],
            path: "Tests/ClipBoardTests"
        ),
    ]
)
