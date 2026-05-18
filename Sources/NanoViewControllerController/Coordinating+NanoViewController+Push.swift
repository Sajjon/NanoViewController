// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCombine
import NanoViewControllerCore
import NanoViewControllerNavigation
import UIKit

public extension Coordinating {
    /// Convenience overload: builds the `NanoViewController` from its type + view-model
    /// and forwards to ``pushSceneInstance(_:animated:navigationPresentationCompletion:navigationHandler:)``.
    ///
    /// This is the single line of code most coordinators use per screen.
    ///
    /// ## Example — push a sign-up controller and route its steps
    ///
    /// ```swift
    /// final class OnboardingCoordinator: BaseCoordinator<OnboardingStep> {
    ///     override func start(didStart: Completion? = nil) {
    ///         let vm = SignUpViewModel(api: api)
    ///         push(scene: SignUpScene.self, viewModel: vm) { [weak self] step in
    ///             guard let self else { return }
    ///             switch step {
    ///             case let .signedUp(user):
    ///                 navigator.next(.finished(user))                // bubble up
    ///             case .userPressedHaveAccount:
    ///                 navigationController.popViewController(animated: true)
    ///             case .userPressedTermsOfService:
    ///                 modallyPresent(scene: LegalScene.self, viewModel: LegalViewModel()) { step, dismiss in
    ///                     // …
    ///                 }
    ///             }
    ///         }
    ///         didStart?()
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - scene: The controller type. Constructed via `S(viewModel: viewModel)`.
    ///   - viewModel: The ViewModel to inject.
    ///   - animated: Animate the push.
    ///   - navigationPresentationCompletion: Fires after the push transition.
    ///   - navigationHandler: Pattern-match on `V.ViewModel.NavigationStep`
    ///     and route each case.
    func push<S: NanoViewController<V>, V: ContentView>(
        scene _: S.Type,
        viewModel: V.ViewModel,
        animated: Bool = true,
        navigationPresentationCompletion: Completion? = nil,
        navigationHandler: @escaping (_ step: V.ViewModel.NavigationStep) -> Void
    ) {
        let scene = S(viewModel: viewModel)
        pushSceneInstance(
            scene,
            animated: animated,
            navigationPresentationCompletion: navigationPresentationCompletion,
            navigationHandler: navigationHandler
        )
    }

    /// Pushes `scene` onto the navigation stack (or sets it as the root if the
    /// stack is empty) and subscribes to its navigation publisher so
    /// coordinator logic can react to user actions and decide when to
    /// advance/pop.
    ///
    /// Use the overload above unless you already have a controller instance.
    ///
    /// - Parameters:
    ///   - scene: A pre-built controller instance.
    ///   - animated: Animate the push.
    ///   - navigationPresentationCompletion: Fires after the push transition.
    ///   - navigationHandler: Pattern-match on `V.ViewModel.NavigationStep`
    ///     and route each case.
    func pushSceneInstance<S: NanoViewController<V>, V: ContentView>(
        _ scene: S,
        animated: Bool = true,
        navigationPresentationCompletion: Completion? = nil,
        navigationHandler: @escaping (_ step: V.ViewModel.NavigationStep) -> Void
    ) {
        navigationController.setRootViewControllerIfEmptyElsePush(
            viewController: scene,
            animated: animated,
            completion: navigationPresentationCompletion
        )

        subscribeToNavigation(of: scene, handler: navigationHandler)
    }
}
