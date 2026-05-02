// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerController
import NanoViewControllerNavigation
import UIKit

/// Root coordinator. Owns the swap between Onboarding and Home flows and
/// keeps a process-lifetime "currently signed-in user" reference (in-memory
/// only — no persistence in the demo).
///
/// Doesn't itself emit any navigation steps: it's the top of the tree, so
/// `NavigationStep` is `Never`.
public final class AppCoordinator: BaseCoordinator<Never> {
    private let window: UIWindow
    private let service: SignUpServicing

    /// Single in-memory record of the signed-in user. `nil` ⇒ run onboarding;
    /// non-nil ⇒ run home. Re-set on signup, cleared on logout.
    private var signedInUser: SignedUpUser?

    public init(
        navigationController: UINavigationController,
        window: UIWindow,
        service: SignUpServicing = DummySignUpService()
    ) {
        self.window = window
        self.service = service
        super.init(navigationController: navigationController)
        window.rootViewController = navigationController
    }

    override public func start(didStart _: Completion? = nil) {
        if let user = signedInUser {
            startHome(with: user)
        } else {
            startOnboarding()
        }
    }
}

// MARK: - Private flows

private extension AppCoordinator {
    func startOnboarding() {
        let onboarding = OnboardingCoordinator(
            navigationController: navigationController,
            service: service
        )
        start(coordinator: onboarding, transition: .replace) { [weak self] step in
            switch step {
            case let .finishedOnboarding(user):
                self?.signedInUser = user
                self?.startHome(with: user)
            }
        }
    }

    func startHome(with user: SignedUpUser) {
        let home = HomeCoordinator(navigationController: navigationController, user: user)
        start(coordinator: home, transition: .replace) { [weak self] step in
            switch step {
            case .loggedOut:
                self?.signedInUser = nil
                self?.startOnboarding()
            }
        }
    }
}
