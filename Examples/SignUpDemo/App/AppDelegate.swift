// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import UIKit

/// Tiny iOS-app shell. The actual scene/window setup lives in
/// ``SceneDelegate``; this delegate just routes the system to the scene
/// configuration declared in `Info.plist`. The interesting code lives in
/// `AppCoordinator`.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // The single scene config registered in `Info.plist` (synthesised
        // from the `INFOPLIST_KEY_UIApplicationSceneManifest_…` build
        // settings in `project.yml`) points at `SceneDelegate`.
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
