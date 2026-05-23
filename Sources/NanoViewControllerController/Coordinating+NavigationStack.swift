// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import NanoViewControllerNavigation
import UIKit

public extension Coordinating {
    /// Returns `true` iff the navigation stack's topmost view controller is
    /// an instance of the supplied view-controller type.
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
    ///   only `ViewController.self` is read.
    /// - Returns: `true` if `navigationController.topViewController is ViewController`.
    func isTopmost<ViewController: UIViewController>(scene _: ViewController.Type) -> Bool {
        guard navigationController.topViewController is ViewController else { return false }
        return true
    }
}
