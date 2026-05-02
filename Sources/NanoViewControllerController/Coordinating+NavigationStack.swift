// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerNavigation
import UIKit

public extension Coordinating {
    /// Returns `true` iff the navigation stack's topmost view controller is
    /// an instance of `Scene`.
    ///
    /// Used by handlers that need to make sure they're reacting to navigation
    /// only when they are the active scene (e.g. avoiding double-pushes from
    /// leftover subscriptions that fire after the user has already navigated
    /// away).
    ///
    /// ## Example — guard a navigation handler against stale events
    ///
    /// ```swift
    /// push(scene: SignUpScene.self, viewModel: vm) { [weak self] step in
    ///     guard let self, isTopmost(scene: SignUpScene.self) else { return }
    ///     // … only run if SignUpScene is still the top of the stack
    /// }
    /// ```
    ///
    /// - Parameter scene: The scene type to test for. Phantom-arg only —
    ///   only `Scene.self` is read.
    /// - Returns: `true` if `navigationController.topViewController is Scene`.
    func isTopmost<Scene: UIViewController>(scene _: Scene.Type) -> Bool {
        guard navigationController.topViewController is Scene else { return false }
        return true
    }
}
