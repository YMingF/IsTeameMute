// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "TeamsMuteOverlay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TeamsMuteOverlayCore", targets: ["TeamsMuteOverlayCore"]),
        .executable(name: "teams-mute-overlay", targets: ["TeamsMuteOverlayApp"]),
        .executable(name: "teams-mute-overlay-meeting-helper", targets: ["TeamsMuteOverlayMeetingHelper"]),
        .executable(name: "teams-mute-spike", targets: ["teams-mute-spike"])
    ],
    targets: [
        .target(
            name: "TeamsMuteOverlayCore",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFAudio"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "TeamsMuteOverlayApp",
            dependencies: ["TeamsMuteOverlayCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "TeamsMuteOverlayMeetingHelper",
            dependencies: ["TeamsMuteOverlayCore"],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "teams-mute-spike",
            dependencies: ["TeamsMuteOverlayCore"]
        ),
        .testTarget(
            name: "TeamsMuteOverlayCoreTests",
            dependencies: ["TeamsMuteOverlayCore"]
        )
    ]
)
