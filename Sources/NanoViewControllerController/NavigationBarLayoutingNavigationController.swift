// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import UIKit

/// `UINavigationController` subclass that re-applies a per-scene
/// ``NavigationBarLayout`` at every navigation transition (push, pop,
/// present, will-appear).
///
/// Why a subclass? `UINavigationBar` is a single shared chrome surface, but
/// each scene wants its own (possibly hidden, possibly translucent)
/// configuration. Without this glue you'd see flashes of stale styling
/// between transitions — a translucent bar from screen N would briefly
/// flash through to screen N+1 mid-push.
///
/// Consumers should always use this subclass (or one of their own derived
/// from it) when seating a coordinator's navigation controller — the package's
/// modal-presentation helpers and replace helpers all assume it.
///
/// Original technique: <https://stackoverflow.com/a/46895818/1311272>
///
/// ## Example
///
/// ```swift
/// // App-level wiring (e.g. inside SceneDelegate):
/// let navController = NavigationBarLayoutingNavigationController()
/// let coord = OnboardingCoordinator(navigationController: navController, api: api)
/// window.rootViewController = navController
/// window.makeKeyAndVisible()
/// coord.start()
/// ```
public final class NavigationBarLayoutingNavigationController: UINavigationController {
    /// The layout most recently applied to the nav bar.
    ///
    /// ``NanoViewController/applyLayoutIfNeeded(_:)`` reads this to skip
    /// re-applying an identical layout — avoids needless animation flickers
    /// when two consecutive scenes use the same layout.
    public var lastLayout: NavigationBarLayout?

    // MARK: - Overridden Methods

    /// Re-applies the top controller's layout when the nav controller itself
    /// reappears (e.g. after a modal dismissal), and installs `self` as the
    /// gesture-recognizer delegate so the swipe-back recognizer can coexist
    /// with custom gestures.
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyLayoutToViewController(topViewController)
        interactivePopGestureRecognizer?.delegate = self
    }

    /// Applies the *destination* controller's layout *before* the push runs, so
    /// the bar already has the right look when the animation starts (no
    /// mid-transition flicker).
    override public func pushViewController(_ viewController: UIViewController, animated: Bool) {
        applyLayoutToViewController(viewController)
        super.pushViewController(viewController, animated: animated)
    }

    /// Same trick as ``pushViewController(_:animated:)`` but for modal
    /// presentation — apply first, then call super.
    override public func present(
        _ viewControllerToPresent: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        applyLayoutToViewController(viewControllerToPresent)
        super.present(viewControllerToPresent, animated: animated, completion: completion)
    }

    /// Pops the top VC, then applies the *new* top VC's layout.
    ///
    /// Order matters: `topViewController` is the destination only after
    /// `super.popViewController` returns.
    @discardableResult
    override public func popViewController(animated: Bool) -> UIViewController? {
        let viewController = super.popViewController(animated: animated)
        applyLayoutToViewController(topViewController)
        return viewController
    }

    /// Pops to a specific VC and applies that VC's layout.
    @discardableResult
    override public func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        let result = super.popToViewController(viewController, animated: animated)
        applyLayoutToViewController(viewController)
        return result
    }

    /// Pops to the root and applies whatever the new top VC needs.
    @discardableResult
    override public func popToRootViewController(animated: Bool) -> [UIViewController]? {
        let result = super.popToRootViewController(animated: animated)
        applyLayoutToViewController(topViewController)
        return result
    }
}

// MARK: - Public Methods

public extension NavigationBarLayoutingNavigationController {
    /// Reads the layout from a ``NanoViewController``'s ``ControllerConfig``
    /// (if present) and applies it.
    ///
    /// No-op if the VC doesn't configure a layout — the previous layout stays.
    /// This is what lets a non-conforming controller "inherit" the previous
    /// controller's bar styling: no override means no change.
    ///
    /// - Parameter viewController: The candidate VC. May be nil after a pop.
    func applyLayoutToViewController(_ viewController: UIViewController?) {
        guard
            let viewController = viewController as? ControllerConfigReadable,
            let navigationBarLayout = viewController.controllerConfig.navigationBarLayout
        else {
            return
        }

        applyLayout(navigationBarLayout)
    }

    /// Applies a ``NavigationBarLayout`` to the underlying `UINavigationBar`,
    /// records it as ``lastLayout``, and updates the bar's hidden/animated
    /// state.
    ///
    /// - Parameter layout: The styling to apply.
    func applyLayout(_ layout: NavigationBarLayout) {
        lastLayout = navigationBar.applyLayout(layout)
        let isHidden = layout.visibility.isHidden
        let animated = layout.visibility.animated
        setNavigationBarHidden(isHidden, animated: animated)
    }
}

// MARK: - UIGestureRecognizerDelegate Methods

extension NavigationBarLayoutingNavigationController: UIGestureRecognizerDelegate {}
public extension NavigationBarLayoutingNavigationController {
    /// Lets the swipe-back recogniser run alongside other recognisers —
    /// required when scenes have their own pan gestures (e.g. cards, sheets).
    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }

    /// Other screen-edge pan recognisers must lose to the system swipe-back
    /// so edge-swipes always pop instead of triggering a custom edge gesture.
    func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer is UIScreenEdgePanGestureRecognizer
    }
}
