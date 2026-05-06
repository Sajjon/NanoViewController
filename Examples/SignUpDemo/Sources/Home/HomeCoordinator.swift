// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import NanoViewControllerController
import NanoViewControllerNavigation
import UIKit

/// Outcome the home flow reports up to its parent (`AppCoordinator`).
public enum HomeNavigationStep: Sendable {
    case loggedOut
}

/// Owns the Home scene. Logout simply forwards `.loggedOut` upward; the
/// AppCoordinator handles tearing the stack and re-running onboarding.
public final class HomeCoordinator: BaseCoordinator<HomeNavigationStep> {
    private let user: SignedUpUser

    public init(navigationController: UINavigationController, user: SignedUpUser) {
        self.user = user
        super.init(navigationController: navigationController)
    }

    override public func start(didStart: Completion? = nil) {
        push(
            scene: HomeScene.self,
            viewModel: HomeViewModel(user: user),
            navigationPresentationCompletion: didStart
        ) { [weak self] userAction in
            switch userAction {
            case .logout:
                self?.navigator.next(.loggedOut)
            }
        }
    }
}
