// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCombine
import NanoViewControllerCore
import NanoViewControllerNavigation

extension Coordinating {
    /// Subscribes the coordinator to the scene's navigation publisher and
    /// stores the resulting cancellable on the coordinator's bag.
    ///
    /// Used by the push-style hookup in
    /// ``Coordinating/pushSceneInstance(_:animated:navigationPresentationCompletion:navigationHandler:)``.
    func subscribeToNavigation<S: Scene<V>, V: ContentView>(
        of scene: S,
        handler: @escaping (V.ViewModel.NavigationStep) -> Void
    ) {
        scene.navigation
            .sinkOnMain { handler($0) }
            .store(in: &cancellables)
    }

    /// Subscribes the coordinator to the scene's navigation publisher and
    /// hands the caller's handler a `DismissScene` callback that dismisses
    /// the scene with optional animation. Used by the modal-style hookups in
    /// ``Coordinating/modallyPresent(scene:animated:presentationCompletion:navigationHandler:)``
    /// and ``Coordinating/replaceAllScenes(with:animated:whenReplacingFinished:navigationHandler:)``.
    func subscribeToModalNavigation<S: Scene<V>, V: ContentView>(
        of scene: S,
        handler: @escaping NavigationHandlerModalScene<V.ViewModel>
    ) {
        scene.navigation
            .sinkOnMain { [weak scene] step in
                handler(step) { animated, completion in
                    scene?.dismiss(animated: animated, completion: completion)
                }
            }
            .store(in: &cancellables)
    }
}
