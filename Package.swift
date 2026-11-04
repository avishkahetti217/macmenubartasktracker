// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TaskTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TaskTracker",
            path: "Sources/TaskTracker",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
