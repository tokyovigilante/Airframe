// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Airframe",
    products: [
        .library(
            name: "Airframe",
            targets: ["Airframe"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tokyovigilante/Harness", .branch("master")),
    ],
    targets: [
        .systemLibrary(
            name: "CWaylandClient",
            pkgConfig: "wayland-client"
        ),
        .systemLibrary(
            name: "CEGL",
            pkgConfig: "egl"
        ),
        .systemLibrary(
            name: "CWaylandEGL",
            pkgConfig: "wayland-egl"
        ),
        .systemLibrary(
            name: "CXKBCommon",
            pkgConfig: "xkbcommon"
        ),
        .target(
            name: "XDGShell",
            dependencies: []
        ),
        .target(
            name: "WaylandShims",
            dependencies: ["Harness"],
            linkerSettings: [
               .linkedLibrary("wayland-client", .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "Airframe",
            dependencies: [
                "CWaylandClient",
                "CEGL",
                "CWaylandEGL",
                "CXKBCommon",
                "Harness",
                "WaylandShims",
                "XDGShell",
            ]
        ),
        .testTarget(
            name: "AirframeTests",
            dependencies: ["Airframe"]),
    ]
)
