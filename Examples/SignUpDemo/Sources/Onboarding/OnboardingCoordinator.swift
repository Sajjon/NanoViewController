// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerController
import NanoViewControllerNavigation
import UIKit

/// Outcome the onboarding flow reports up to its parent (`AppCoordinator`).
public enum OnboardingNavigationStep: Sendable {
    case finishedOnboarding(SignedUpUser)
}

/// Owns the SignUp scene. Currently the entire onboarding is one screen, but
/// keeping it behind a coordinator means new steps (e.g. terms-of-service,
/// email verification) can slot in here without touching `AppCoordinator`.
public final class OnboardingCoordinator: BaseCoordinator<OnboardingNavigationStep> {
    private let service: SignUpServicing

    public init(navigationController: UINavigationController, service: SignUpServicing) {
        self.service = service
        super.init(navigationController: navigationController)
    }

    override public func start(didStart: Completion? = nil) {
        push(
            scene: SignUpScene.self,
            viewModel: SignUpViewModel(service: service),
            navigationPresentationCompletion: didStart
        ) { [weak self] userAction in
            switch userAction {
            case let .signedUp(user):
                self?.navigator.next(.finishedOnboarding(user))
            }
        }
    }
}
