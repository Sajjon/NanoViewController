// swift-tools-version: 5.9
//
// NanoViewController — UIKit + Combine MVVM-C scaffolding extracted from
// the Zhip wallet codebase.
//
// Library products:
//
//   NanoViewControllerCore           value types only; no UIKit
//   NanoViewControllerCombine        Combine helpers + Binder + --> operator
//   NanoViewControllerNavigation     Coordinator pattern + Navigator
//   NanoViewControllerController     SceneController, BarButton plumbing, nav-bar layout
//   NanoViewControllerSceneViews     AbstractSceneView + SingleCellTypeTableView
//   NanoViewControllerDIPrimitives   protocol-only DI (Clock, MainScheduler, …)
//
// Originally lived inside Zhip as `SingleLineController*` modules; ported
// from RxSwift to Combine and extracted here. See README for history.

import PackageDescription

let package = Package(
    name: "NanoViewController",
    // macOS 13 listed alongside iOS so `swift build` / `swift test` on a
    // macOS host can exercise the Combine APIs. The actual consumer is
    // iOS-only; the macOS minimum exists only for host-side runs.
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "NanoViewControllerCore", targets: ["NanoViewControllerCore"]),
        .library(name: "NanoViewControllerCombine", targets: ["NanoViewControllerCombine"]),
        .library(name: "NanoViewControllerNavigation", targets: ["NanoViewControllerNavigation"]),
        .library(name: "NanoViewControllerController", targets: ["NanoViewControllerController"]),
        .library(name: "NanoViewControllerSceneViews", targets: ["NanoViewControllerSceneViews"]),
        .library(name: "NanoViewControllerDIPrimitives", targets: ["NanoViewControllerDIPrimitives"]),
    ],
    targets: [
        .target(name: "NanoViewControllerCore"),
        .target(
            name: "NanoViewControllerCombine",
            dependencies: ["NanoViewControllerCore"]
        ),
        .target(
            name: "NanoViewControllerNavigation",
            dependencies: ["NanoViewControllerCore"]
        ),
        .target(
            name: "NanoViewControllerController",
            dependencies: [
                "NanoViewControllerCore",
                "NanoViewControllerCombine",
                "NanoViewControllerNavigation",
                "NanoViewControllerDIPrimitives",
            ]
        ),
        .target(
            name: "NanoViewControllerSceneViews",
            dependencies: [
                "NanoViewControllerCore",
                "NanoViewControllerCombine",
                "NanoViewControllerController",
            ]
        ),
        .target(name: "NanoViewControllerDIPrimitives"),

        .testTarget(
            name: "NanoViewControllerCoreTests",
            dependencies: ["NanoViewControllerCore"]
        ),
        .testTarget(
            name: "NanoViewControllerCombineTests",
            dependencies: ["NanoViewControllerCombine"]
        ),
    ]
)
