// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCombine
import NanoViewControllerCore
import NanoViewControllerNavigation
import UIKit

public extension Coordinating {
    /// Convenience overload: builds the `Scene` from its type + view-model and
    /// forwards to ``modallyPresent(scene:animated:presentationCompletion:navigationHandler:)``.
    ///
    /// ## Example — present a modal "legal" scene
    ///
    /// ```swift
    /// modallyPresent(
    ///     scene: LegalScene.self,
    ///     viewModel: LegalViewModel()
    /// ) { step, dismiss in
    ///     switch step {
    ///     case .userTappedDone: dismiss(true, nil)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - scene: The scene type. The function constructs an instance via
    ///     `S(viewModel: viewModel)`.
    ///   - viewModel: The ViewModel to inject.
    ///   - animated: Whether the modal presentation animates. Default `true`.
    ///   - presentationCompletion: Optional callback fired after presentation.
    ///   - navigationHandler: Step-handling closure. The trailing
    ///     ``DismissScene`` is how the caller dismisses this modal.
    func modallyPresent<S: Scene<V>, V: ContentView>(
        scene _: S.Type,
        viewModel: V.ViewModel,
        animated: Bool = true,
        presentationCompletion: Completion? = nil,
        navigationHandler: @escaping NavigationHandlerModalScene<V.ViewModel>
    ) {
        let scene = S(viewModel: viewModel)
        modallyPresent(
            scene: scene,
            animated: animated,
            presentationCompletion: presentationCompletion,
            navigationHandler: navigationHandler
        )
    }

    /// Wraps `scene` in its own ``NavigationBarLayoutingNavigationController``
    /// and presents it modally on `self.navigationController`.
    ///
    /// Subscribes to the scene's view-model navigator so coordinator-level
    /// handling can react to user actions and dismiss when appropriate.
    ///
    /// Use the overload above unless you already have a `Scene` instance —
    /// the typed-form version saves a line at the call site.
    ///
    /// - Parameters:
    ///   - scene: A pre-built scene instance.
    ///   - animated: Animate presentation.
    ///   - presentationCompletion: Fires after presentation completes.
    ///   - navigationHandler: Step-handling closure. Use the trailing
    ///     ``DismissScene`` to dismiss.
    func modallyPresent<S: Scene<V>, V: ContentView>(
        scene: S,
        animated: Bool = true,
        presentationCompletion: Completion? = nil,
        navigationHandler: @escaping NavigationHandlerModalScene<V.ViewModel>
    ) {
        // Wrap in a nav controller so the modal sheet has its own navigation
        // bar (and our shared layout owner machinery still works).
        let viewControllerToPresent = NavigationBarLayoutingNavigationController(rootViewController: scene)
        navigationController.present(viewControllerToPresent, animated: animated, completion: presentationCompletion)

        // Bridge the scene's navigation pulses to the caller's handler,
        // handing the handler a closure it can call to dismiss this modal.
        scene.navigation
            .sinkOnMain { [weak scene] step in
                navigationHandler(step) { animated, navigationCompletion in
                    scene?.dismiss(animated: animated, completion: navigationCompletion)
                }
            }
            .store(in: &cancellables)
    }
}
