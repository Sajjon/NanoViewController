// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

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
///
/// ## Unit-testing the routing closure
///
/// The trailing closure passed to `push(...)` below is captured by NVC's
/// internal Combine subscription. Tests that want to assert "when the user
/// finishes signing up, `OnboardingCoordinator` bubbles `.finishedOnboarding`
/// up to its parent" would otherwise have to drive the full view → view-model
/// → navigator → Combine pipeline through UIKit.
///
/// NVC exposes the same closure on the scene controller as
/// ``NanoViewController/navigationHandler`` under `@_spi(Testing)`, so tests
/// can drive routing directly:
///
/// ```swift
/// @_spi(Testing) import NanoViewControllerController
///
/// func test_signUpFinish_bubblesFinishedOnboarding() {
///     let nav = UINavigationController()
///     let coordinator = OnboardingCoordinator(navigationController: nav, service: StubService())
///     var bubbledStep: OnboardingNavigationStep?
///     coordinator.navigator.navigation.sink { bubbledStep = $0 }.store(in: &cancellables)
///
///     coordinator.start()
///     let scene = nav.viewControllers.first as! SignUpScene
///     scene.navigationHandler?(.signedUp(SignedUpUser(id: "u1", name: "Test", email: "t@x")))
///     pumpMainRunLoop()
///
///     guard case .finishedOnboarding = bubbledStep else { return XCTFail("...") }
/// }
/// ```
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
