// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCombine
import NanoViewControllerCore
import NanoViewControllerNavigation

extension Coordinating {
    /// Subscribes to the controller's navigation publisher and stashes the
    /// cancellable on the scene itself, so re-subscribing through the inverse
    /// helper (see ``subscribeToModalNavigation(of:handler:)``) cancels this
    /// subscription instead of letting both sinks fire on every emission.
    ///
    /// Used by the push-style hookup in
    /// ``Coordinating/pushSceneInstance(_:animated:navigationPresentationCompletion:navigationHandler:)``.
    ///
    /// Side effect: stashes `handler` on
    /// ``NanoViewController/navigationHandler`` (an `@_spi(Testing)` hook) so
    /// tests can invoke coordinator routing directly without driving the
    /// view-model's Combine pipeline. Production callers don't see this
    /// property unless they opt in via `@_spi(Testing) import`.
    ///
    /// Clears ``NanoViewController/modalNavigationHandler`` to keep the two
    /// SPI hooks mutually exclusive — the live handler is whichever helper
    /// last subscribed.
    func subscribeToNavigation<S: NanoViewController<V>, V: ContentView>(
        of scene: S,
        handler: @escaping (V.ViewModel.NavigationStep) -> Void
    ) {
        scene.navigationHandler = handler
        scene.modalNavigationHandler = nil
        scene.navigationSubscription = scene.navigation
            .sinkOnMain { handler($0) }
    }

    /// Subscribes to the controller's navigation publisher and hands the
    /// caller's handler a `DismissScene` callback that dismisses the
    /// controller with optional animation. Used by the modal-style hookups in
    /// ``Coordinating/modallyPresent(scene:animated:presentationCompletion:navigationHandler:)``
    /// and ``Coordinating/replaceAllScenes(with:animated:whenReplacingFinished:navigationHandler:)``.
    ///
    /// Like the push-style variant, the cancellable lives on the scene so
    /// that re-subscribing through ``subscribeToNavigation(of:handler:)``
    /// cancels this subscription rather than leaving two live sinks routing
    /// every emission to both handlers.
    ///
    /// Side effect: stashes `handler` on
    /// ``NanoViewController/modalNavigationHandler`` (an `@_spi(Testing)` hook).
    /// Tests pass a spy ``DismissScene`` when invoking the handler so the
    /// dismissal side-effect is observable without a real modal presentation.
    ///
    /// Clears ``NanoViewController/navigationHandler`` to keep the two SPI
    /// hooks mutually exclusive — the live handler is whichever helper last
    /// subscribed.
    func subscribeToModalNavigation<S: NanoViewController<V>, V: ContentView>(
        of scene: S,
        handler: @escaping ModalNavigationHandler<V.ViewModel>
    ) {
        scene.modalNavigationHandler = handler
        scene.navigationHandler = nil
        scene.navigationSubscription = scene.navigation
            .sinkOnMain { [weak scene] step in
                handler(step) { animated, completion in
                    scene?.dismiss(animated: animated, completion: completion)
                }
            }
    }
}
