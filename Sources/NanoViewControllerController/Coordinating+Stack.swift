// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerCore
import NanoViewControllerNavigation
import UIKit

public extension Coordinating {
    /// Identity-based lookup of `child` in `childCoordinators`.
    ///
    /// Identity (rather than equality) because coordinators are
    /// `AnyObject`-only — there is no meaningful `Equatable` notion for a
    /// flow object.
    ///
    /// - Parameter child: The coordinator to find.
    /// - Returns: The first matching index, or `nil`.
    func firstIndexOf(child: Coordinating) -> Int? {
        childCoordinators.firstIndex(where: { $0 === child })
    }

    /// Removes `child` from `childCoordinators`.
    ///
    /// Crashes via ``incorrectImplementation(_:)`` if the child cannot be
    /// found — that means a coordinator was started without being added to
    /// the parent's stack and we'd leak it. Also crashes if a duplicate copy
    /// remains after removal (would also leak through).
    ///
    /// ## Example — modal coordinator pattern
    ///
    /// ```swift
    /// // ModalCoordinator's flow finishes; remove it from its parent.
    /// child.navigator.navigation
    ///     .sink { [weak self, weak child] step in
    ///         switch step {
    ///         case .finished:
    ///             child.flatMap { self?.remove(childCoordinator: $0) }
    ///         }
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// - Parameter child: The coordinator to remove. Must currently be a child.
    func remove(childCoordinator child: Coordinating) {
        guard let index = firstIndexOf(child: child) else {
            incorrectImplementation(
                "Should and must be able to find child coordinator and remove it in order to avoid memory leaks."
            )
        }
        childCoordinators.remove(at: index)

        // Sanity-check that we removed the only copy. Duplicate appends would
        // produce a leak that survives this call — fail loudly during dev.
        guard firstIndexOf(child: child) == nil else {
            incorrectImplementation(
                "Child coordinators should not contain the instance of `\(child)` after it have been removed"
            )
        }
    }

    /// Recursively descends through `childCoordinators` and returns the
    /// deepest active coordinator (the one whose own `childCoordinators` is
    /// empty).
    ///
    /// Useful for handlers that want to act on "wherever the user currently
    /// is" without the caller knowing the coordinator tree's depth.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Pop to root from anywhere in the tree.
    /// appCoordinator.topMostCoordinator.navigationController.popToRootViewController(animated: true)
    /// ```
    var topMostCoordinator: Coordinating {
        guard let last = childCoordinators.last else { return self }
        return last.topMostCoordinator
    }

    /// The ``AbstractController`` currently visible on screen, taking into
    /// account modal presentations.
    ///
    /// Used by toast presentation so a toast is shown on top of any modal
    /// that's currently up.
    ///
    /// ## Example — show a toast from anywhere in the tree
    ///
    /// ```swift
    /// // Surface a toast on the topmost scene, modal or not.
    /// if let scene = appCoordinator.topMostScene {
    ///     Toast("Synced").present(using: scene, clock: MainQueueClock())
    /// }
    /// ```
    var topMostScene: AbstractController? {
        if let presentedController = topMostCoordinator.navigationController.presentedViewController {
            if let presentedNavigationController = presentedController as? UINavigationController {
                return presentedNavigationController.topViewController as? AbstractController
            } else {
                return presentedController as? AbstractController
            }
        } else {
            return topMostCoordinator.navigationController.topViewController as? AbstractController
        }
    }
}
