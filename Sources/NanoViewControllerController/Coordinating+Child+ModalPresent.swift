// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCombine
import NanoViewControllerNavigation
import UIKit

// MARK: - Start Child Coordinator

public extension Coordinating {
    /// Starts a new temporary flow with a new Coordinator presented modally.
    ///
    /// The child coordinator is initialised by the call-site in
    /// `makeCoordinator`, which receives a fresh `UINavigationController`.
    /// The `navigationHandler` closure receives each `NavigationStep` plus a
    /// `dismiss` closure the caller invokes when the flow finishes — that
    /// dismiss tears down the navigation stack AND removes the child from
    /// `childCoordinators`.
    ///
    /// Use this for short-lived modal sub-flows that the *parent* decides
    /// when to finish (i.e. the child's job is to gather user-actions and
    /// surface them via its own navigator; the parent dismisses on a
    /// terminal action). For long-lived sub-flows that finish themselves,
    /// use ``Coordinating/start(coordinator:transition:didStart:navigationHandler:)``.
    ///
    /// ## Example — modal "edit profile" sub-flow
    ///
    /// ```swift
    /// final class HomeCoordinator: BaseCoordinator<HomeStep> {
    ///     private func presentEditProfile() {
    ///         presentModalCoordinator(
    ///             makeCoordinator: { newNav in
    ///                 EditProfileCoordinator(navigationController: newNav, api: api)
    ///             }
    ///         ) { step, dismiss in
    ///             switch step {
    ///             case .userCancelled:        dismiss(true)
    ///             case .userTappedSave:       dismiss(true)        // parent decides when to dismiss
    ///             case .userPressedAvatar:    /* push another VC inside the modal */
    ///                 break
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - makeCoordinator: Factory that builds the child coordinator. Receives
    ///     the fresh modal `UINavigationController` to seat the child on.
    ///   - didStart: Optional callback fired after `child.start()` completes.
    ///   - navigationHandler: Closure invoked for every navigation step the
    ///     child emits. The trailing `dismiss` callback tears down the modal
    ///     and removes the child from `childCoordinators`.
    func presentModalCoordinator<C: Coordinating & Navigating>(
        makeCoordinator: (_ newNavController: UINavigationController) -> C,
        didStart: Completion? = nil,
        navigationHandler: @escaping (_ step: C.NavigationStep, _ dismiss: (_ animateDismiss: Bool) -> Void) -> Void
    ) {
        let newModalNavigationController = NavigationBarLayoutingNavigationController()

        let child = makeCoordinator(newModalNavigationController)

        childCoordinators.append(child)

        child.start(didStart: didStart)

        navigationController.present(newModalNavigationController, animated: true, completion: nil)

        // Subscribe to the navigation steps emitted by the child coordinator
        // and invoke the `navigationHandler` closure. When the parent invokes
        // the trailing `dismiss` closure we tear down the modal AND remove
        // the child from `childCoordinators` so it can be deallocated.
        child.navigator.navigation
            .sinkOnMain { [
                weak self,
                weak newModalNavigationController,
                weak child
            ] navigationStep in
                navigationHandler(navigationStep) { animated in
                    newModalNavigationController?.dismiss(animated: animated, completion: nil)
                    if let self, let child {
                        self.remove(childCoordinator: child)
                    }
                }
            }
            .store(in: &cancellables)
    }
}
