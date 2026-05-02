// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerController
import UIKit

/// Tiny iOS-app shell. The interesting code lives in `AppCoordinator`.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Pre-iOS-13-style single-window setup keeps the example small (no
    /// SceneDelegate, no Info.plist scene manifest).
    var window: UIWindow?

    /// Lazy because we need `window` to exist first so the coordinator can
    /// install/replace its rootViewController.
    private lazy var appCoordinator: AppCoordinator = .init(
        navigationController: NavigationBarLayoutingNavigationController(),
        window: window!
    )

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        appCoordinator.start()
        window.makeKeyAndVisible()
        return true
    }
}
