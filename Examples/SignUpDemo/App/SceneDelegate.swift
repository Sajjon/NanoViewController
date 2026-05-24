// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import NanoViewControllerController
import UIKit

/// iOS 13+/26-correct scene-based window setup. Builds the `UIWindow` from
/// the scene's `windowScene` (so `UIWindow.init(frame:)` and
/// `UIScreen.main` — both deprecated in iOS 26 — stay out of the example).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    /// Lazy because we need `window` to exist first so the coordinator can
    /// install/replace its `rootViewController`. Force-unwrap is fine: this
    /// closure runs from `scene(_:willConnectTo:options:)` *after* `window`
    /// has been assigned.
    private lazy var appCoordinator: AppCoordinator = .init(
        navigationController: NavigationBarLayoutingNavigationController(),
        window: window!
    )

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        appCoordinator.start()
        window.makeKeyAndVisible()
    }
}
