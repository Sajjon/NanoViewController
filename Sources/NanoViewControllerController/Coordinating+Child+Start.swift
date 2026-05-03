// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import NanoViewControllerCombine
import NanoViewControllerNavigation
import UIKit

public extension Coordinating {
    /// Starts a child coordinator which might be part of a flow of multiple
    /// coordinators.
    ///
    /// Use this method when you know that you will finish the root coordinator
    /// at some point, which also will finish this new child coordinator.
    ///
    /// If you intend to start a single temporary coordinator that you will
    /// finish from the parent (the coordinator instance you called this method
    /// on), use ``Coordinating/presentModalCoordinator(makeCoordinator:didStart:navigationHandler:)``
    /// instead.
    ///
    /// ## Example — append a child sub-flow
    ///
    /// ```swift
    /// final class OnboardingCoordinator: BaseCoordinator<OnboardingStep> {
    ///     override func start(didStart: Completion? = nil) {
    ///         showWelcome()
    ///     }
    ///
    ///     private func toCreateWallet() {
    ///         let create = CreateWalletCoordinator(navigationController: navigationController, api: api)
    ///         start(coordinator: create) { [weak self] step in
    ///             switch step {
    ///             case let .created(wallet): self?.toBackup(wallet)
    ///             case .userCancelled:        self?.navigationController.popViewController(animated: true)
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ## Example — replace the entire stack (e.g. logout → onboarding)
    ///
    /// ```swift
    /// final class AppCoordinator: BaseCoordinator<Never> {
    ///     private func showOnboarding() {
    ///         let onboarding = OnboardingCoordinator(navigationController: navigationController, api: api)
    ///         start(coordinator: onboarding, transition: .replace) { [weak self] step in
    ///             switch step {
    ///             case .finished: self?.showMain()
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - child: The new child coordinator. Will be appended to (or replace)
    ///     `childCoordinators`.
    ///   - transition: How to mount it — ``CoordinatorTransition/append`` (the
    ///     default, stacks on top) or ``CoordinatorTransition/replace`` (wipes
    ///     the existing nav stack first).
    ///   - didStart: Optional callback fired after `child.start()` completes.
    ///   - navigationHandler: Closure invoked for every navigation step the
    ///     child emits. Pattern-match on `C.NavigationStep` and route.
    func start<C: Coordinating & Navigating>(
        coordinator child: C,
        transition: CoordinatorTransition = .append,
        didStart: Completion? = nil,
        navigationHandler: @escaping (_ step: C.NavigationStep) -> Void
    ) {
        // Start the child coordinator and pass along the `didStart` closure.
        let startChild = { [weak child] in
            child?.start(didStart: didStart)
        }

        // Add the child coordinator to the childCoordinator array.
        switch transition {
        case .replace:
            // .replace wipes the current navigation stack first so the user
            // doesn't see the previous flow's controllers flash through.
            // Starting the child is deferred to the wipe's completion.
            childCoordinators = [child]
            navigationController.removeAllViewControllers { startChild() }
        case .append:
            // .append keeps the existing stack and starts the child synchronously.
            childCoordinators.append(child)
            startChild()
        }

        // Subscribe to the navigation steps emitted by the child coordinator
        // and invoke the navigationHandler closure passed in to this method.
        child.navigator.navigation
            .sinkOnMain { navigationHandler($0) }
            .store(in: &cancellables)
    }
}

private extension UINavigationController {
    /// Empties the navigation stack and any presented controller, invoking
    /// `completion` once the teardown finishes.
    ///
    /// Used by ``CoordinatorTransition/replace`` to clear the slate before
    /// starting the replacement child. If a modal is up, the modal is
    /// dismissed first so its reference into our `viewControllers` doesn't
    /// become stale.
    ///
    /// - Parameters:
    ///   - animated: Whether to animate the teardown. Default `true`.
    ///   - completion: Fires after the stack has been emptied (and any modal
    ///     dismissed).
    func removeAllViewControllers(animated: Bool = true, completion: @escaping Completion) {
        func removeAllViewControllers() {
            if !viewControllers.isEmpty {
                viewControllers = []
            }
            // Hop to the next runloop tick so callers observe the empty
            // viewControllers array, not the in-flight one.
            DispatchQueue.main.async { completion() }
        }

        // If a modal is up, we must dismiss it before clearing the stack —
        // otherwise the modal's reference into our viewControllers becomes stale.
        if let presented = presentedViewController {
            presented.dismiss(animated: animated) {
                removeAllViewControllers()
            }
        } else {
            removeAllViewControllers()
        }
    }
}
