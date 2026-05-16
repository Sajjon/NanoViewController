// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCombine
import NanoViewControllerCore
import NanoViewControllerNavigation
import UIKit

public extension Coordinating {
    /// Closure shape used by ``modallyPresent(scene:viewModel:animated:presentationCompletion:navigationHandler:)``
    /// and ``replaceAllScenes(with:viewModel:animated:whenReplacingFinished:navigationHandler:)``:
    /// receives the next navigation step plus a ``DismissScene`` callback the
    /// handler can invoke to dismiss the presenting controller with optional
    /// animation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// modallyPresent(scene: SettingsScene.self, viewModel: vm) { step, dismiss in
    ///     switch step {
    ///     case .userTappedDone:    dismiss(true, nil)
    ///     case .userTappedAccount: /* push another VC inside the modal */ break
    ///     }
    /// }
    /// ```
    typealias ModalNavigationHandler<VM: ViewModelType> = (VM.NavigationStep, @escaping DismissScene) -> Void

    /// Replaces every controller in the current navigation stack with `scene`.
    ///
    /// Use when transitioning to a *fresh* root for the same nav controller
    /// (e.g. logout → login). The previous stack is dismissed in
    /// `whenReplacingFinished` so any in-flight modal teardowns don't race
    /// with the new root push.
    ///
    /// ## Example — logout flow
    ///
    /// ```swift
    /// final class AppCoordinator: BaseCoordinator<Never> {
    ///     func logout() {
    ///         let vm = LoginViewModel(api: api)
    ///         replaceAllScenes(with: LoginScene.self, viewModel: vm) { step, dismiss in
    ///             switch step {
    ///             case let .loggedIn(user):
    ///                 // Replace AGAIN to swap to the home scene.
    ///                 self.showHome(for: user)
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    func replaceAllScenes<S: NanoViewController<V>, V: ContentView>(
        with _: S.Type,
        viewModel: V.ViewModel,
        animated: Bool = true,
        whenReplacingFinished: Completion? = nil,
        navigationHandler: @escaping ModalNavigationHandler<V.ViewModel>
    ) {
        // Create a new instance of the controller, injecting its ViewModel.
        let scene = S(viewModel: viewModel)

        replaceAllScenes(
            with: scene,
            animated: animated,
            whenReplacingFinished: whenReplacingFinished,
            navigationHandler: navigationHandler
        )
    }

    /// Instance-level variant of
    /// ``replaceAllScenes(with:viewModel:animated:whenReplacingFinished:navigationHandler:)``.
    ///
    /// Use when you already have a controller instance.
    func replaceAllScenes<S: NanoViewController<V>, V: ContentView>(
        with scene: S,
        animated: Bool = true,
        whenReplacingFinished: Completion? = nil,
        navigationHandler: @escaping ModalNavigationHandler<V.ViewModel>
    ) {
        let oldVCs = navigationController.viewControllers

        navigationController.setRootViewControllerIfEmptyElsePush(
            viewController: scene,
            animated: animated,
            forceReplaceAllVCsInsteadOfPush: true
        ) {
            whenReplacingFinished?()
            oldVCs.forEach { $0.dismiss(animated: false, completion: nil) }
        }

        subscribeToModalNavigation(of: scene, handler: navigationHandler)
    }
}

public extension UINavigationController {
    /// Smart push: pushes `viewController` if there is already at least one
    /// VC on the stack; otherwise sets it as the single root.
    ///
    /// Pass `forceReplaceAllVCsInsteadOfPush: true` to clear the stack
    /// regardless. Calls `completion` after the transition (animated or not).
    ///
    /// ## Example
    ///
    /// ```swift
    /// // First controller of a flow — sets root if empty, pushes otherwise.
    /// navigationController.setRootViewControllerIfEmptyElsePush(
    ///     viewController: SignUpScene(viewModel: vm)
    /// )
    ///
    /// // Replacement — wipes the stack regardless.
    /// navigationController.setRootViewControllerIfEmptyElsePush(
    ///     viewController: HomeScene(viewModel: vm),
    ///     forceReplaceAllVCsInsteadOfPush: true
    /// )
    /// ```
    func setRootViewControllerIfEmptyElsePush(
        viewController: UIViewController,
        animated: Bool = true,
        forceReplaceAllVCsInsteadOfPush: Bool = false,
        completion: Completion? = nil
    ) {
        // Track whether the actual transition we performed was animated, so
        // the completion-routing below uses the right branch. (Forcing
        // `animated: false` on the empty-stack branch below means the
        // caller-supplied `animated: true` doesn't apply for that path.)
        let didAnimate: Bool
        if viewControllers.isEmpty, viewIfLoaded?.window == nil {
            // Only suppress the initial empty-stack animation when this nav
            // controller is still off-screen. Typical case: a brand-new
            // modal nav controller that is about to be
            // `present(animated: true)`-ed by the caller. In contrast, an
            // already-visible nav controller may temporarily have an empty
            // stack during a `.replace` flow, and that first insertion is the
            // user-visible transition, so it must continue to honor
            // `animated`.
            setViewControllers([viewController], animated: false)
            didAnimate = false
        } else if forceReplaceAllVCsInsteadOfPush {
            setViewControllers([viewController], animated: animated)
            didAnimate = animated
        } else {
            pushViewController(viewController, animated: animated)
            didAnimate = animated
        }

        // Add extra functionality to pass a "completion" closure even for
        // `push`ed ViewControllers (UIKit doesn't ship a push-with-completion API).
        guard let completion else { return }
        // If there is no transition coordinator (i.e. we set VCs without an
        // animation context, or forced animated:false above), schedule the
        // completion for the next runloop tick so callers observe a fully-
        // applied stack.
        guard didAnimate, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async { completion() }
            return
        }
        coordinator.animate(alongsideTransition: nil) { _ in completion() }
    }
}

public extension UINavigationController {
    /// `popToRootViewController(animated:)` with a completion callback that
    /// fires after the pop animation finishes (or on the next runloop tick
    /// if no transition coordinator is available).
    ///
    /// ## Example
    ///
    /// ```swift
    /// navigationController.popToRootViewController(animated: true) {
    ///     // Now the home scene is the only one on the stack.
    ///     self.refreshHome()
    /// }
    /// ```
    func popToRootViewController(animated: Bool = true, completion: @escaping Completion) {
        popToRootViewController(animated: animated)
        guard animated, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async { completion() }
            return
        }
        coordinator.animate(alongsideTransition: nil) { _ in completion() }
    }
}
