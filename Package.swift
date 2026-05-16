// swift-tools-version: 6.2
//
// NanoViewController — UIKit + Combine MVVM-C scaffolding extracted from
// the Zhip wallet codebase.
//
// Library products:
//
//   NanoViewControllerCore           value types only; no UIKit
//   NanoViewControllerCombine        Combine helpers + Binder + --> operator
//   NanoViewControllerNavigation     Coordinator pattern + Navigator
//   NanoViewControllerController     NanoViewController, BarButton plumbing, nav-bar layout
//   NanoViewControllerSceneViews     AbstractSceneView + SingleCellTypeTableView
//   NanoViewControllerDIPrimitives   protocol-only DI (Clock, MainScheduler, …)
//
// Originally lived inside Zhip as `SingleLineController*` modules; ported
// from RxSwift to Combine and extracted here. See README for history.

import PackageDescription

// Compile every target in Swift 6 language mode. iOS 26's UIKit ships
// with `UIView`, `UIViewController`, `UITableViewCell`, etc. annotated
// `@MainActor`; the package's UI-bound surface is correspondingly
// `@MainActor` (protocols, classes, `@MainActor`-isolated view-model
// hierarchy, `Navigator`/`Coordinating`, the DI primitives that touch
// UIKit). Value structs (`BarButtonContent`, `NavigationBarLayout`)
// are plain `Sendable`. The only `@unchecked Sendable` left is
// `UIControlSubscription` — Combine's `Subscription` protocol is
// non-isolated, so a `@MainActor` class can't directly conform; the
// `@unchecked` is documented in-source with the actual invariants.
let swift6Mode: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
]

let package = Package(
    name: "NanoViewController",
    // iOS 26 minimum: the package's `@MainActor` annotations match
    // iOS 26's UIKit isolation model. macOS 14 listed so `swift build` /
    // `swift test` on a macOS host can exercise the Combine APIs; the
    // actual consumer is iOS-only.
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "NanoViewControllerCore", targets: ["NanoViewControllerCore"]),
        .library(name: "NanoViewControllerCombine", targets: ["NanoViewControllerCombine"]),
        .library(name: "NanoViewControllerNavigation", targets: ["NanoViewControllerNavigation"]),
        .library(name: "NanoViewControllerController", targets: ["NanoViewControllerController"]),
        .library(name: "NanoViewControllerSceneViews", targets: ["NanoViewControllerSceneViews"]),
        .library(name: "NanoViewControllerDIPrimitives", targets: ["NanoViewControllerDIPrimitives"]),
    ],
    targets: [
        .target(
            name: "NanoViewControllerCore",
            swiftSettings: swift6Mode
        ),
        .target(
            name: "NanoViewControllerCombine",
            dependencies: ["NanoViewControllerCore"],
            swiftSettings: swift6Mode
        ),
        .target(
            name: "NanoViewControllerNavigation",
            dependencies: ["NanoViewControllerCore"],
            swiftSettings: swift6Mode
        ),
        .target(
            name: "NanoViewControllerController",
            dependencies: [
                "NanoViewControllerCore",
                "NanoViewControllerCombine",
                "NanoViewControllerNavigation",
                "NanoViewControllerDIPrimitives",
            ],
            swiftSettings: swift6Mode
        ),
        .target(
            name: "NanoViewControllerSceneViews",
            dependencies: [
                "NanoViewControllerCore",
                "NanoViewControllerCombine",
                "NanoViewControllerController",
            ],
            swiftSettings: swift6Mode
        ),
        .target(
            name: "NanoViewControllerDIPrimitives",
            swiftSettings: swift6Mode
        ),

        .testTarget(
            name: "NanoViewControllerCoreTests",
            dependencies: ["NanoViewControllerCore"],
            swiftSettings: swift6Mode
        ),
        .testTarget(
            name: "NanoViewControllerControllerTests",
            dependencies: ["NanoViewControllerController"],
            swiftSettings: swift6Mode
        ),
        .testTarget(
            name: "NanoViewControllerCombineTests",
            dependencies: ["NanoViewControllerCombine"],
            swiftSettings: swift6Mode
        ),
        .testTarget(
            name: "NanoViewControllerDIPrimitivesTests",
            dependencies: ["NanoViewControllerDIPrimitives"],
            swiftSettings: swift6Mode
        ),
    ]
)
