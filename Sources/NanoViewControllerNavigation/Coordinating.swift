// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import UIKit

/// Standard "no-arg, no-return" completion closure used throughout navigation.
///
/// Used as the trailing closure on push/present/dismiss calls so the caller
/// can chain "do this once the transition finishes" work without having to
/// import UIKit's transition-coordinator types.
public typealias Completion = () -> Void

/// Closure signature handed to navigation handlers so they can dismiss the
/// scene they were just told to navigate from.
///
///   * `animatedDismiss` — `true` to animate the dismissal, `false` for an
///     immediate teardown.
///   * `presentationCompletion` — optional callback that fires *after* the
///     dismiss animation finishes.
///
/// ## Example
///
/// ```swift
/// coordinator.modallyPresent(scene: SettingsScene.self, viewModel: vm) { step, dismiss in
///     switch step {
///     case .userTappedDone:
///         dismiss(true) { print("settings closed") }
///     case .userTappedSomeSubFlow:
///         // … push something else without dismissing yet
///         break
///     }
/// }
/// ```
public typealias DismissScene = (_ animatedDismiss: Bool, _ presentationCompletion: Completion?) -> Void

/// The contract every coordinator implements.
///
/// A *Coordinator* owns the navigation logic for one logical flow — onboarding,
/// settings, a sub-task within a parent flow. Each coordinator drives one
/// `UINavigationController`, holds a list of ``childCoordinators`` for nested
/// sub-flows, and exposes navigation pulses through a ``Navigator``.
///
/// The package ships every helper as an *extension on `Coordinating`*: modal
/// presentation, push, replace, child-coordinator stack management, debug
/// printing, top-most lookup. So conforming once gives you all of those for
/// free.
///
/// `CustomStringConvertible` is *not* a constraint here: consumers that want a
/// rich coordinator-tree dump declare conformance themselves and provide the
/// `description` (Zhip's `Coordinating+DebugPrinting.swift` does this with a
/// `stringRepresentation(level:)` helper).
///
/// ## Example — minimal custom coordinator
///
/// ```swift
/// import Combine
/// import NanoViewControllerNavigation
/// import NanoViewControllerController
/// import UIKit
///
/// enum OnboardingStep { case finished }
///
/// final class OnboardingCoordinator: BaseCoordinator<OnboardingStep> {
///     private let api: API
///     init(navigationController: UINavigationController, api: API) {
///         self.api = api
///         super.init(navigationController: navigationController)
///     }
///
///     override func start(didStart: Completion? = nil) {
///         let vm = WelcomeViewModel(api: api)
///         push(scene: WelcomeScene.self, viewModel: vm) { [weak self] step in
///             switch step {
///             case .userPressedSignUp:    self?.toSignUp()
///             case .userPressedHaveAccount: self?.toLogin()
///             }
///         }
///         didStart?()
///     }
///
///     private func toSignUp() {
///         let vm = SignUpViewModel(api: api)
///         push(scene: SignUpScene.self, viewModel: vm) { [weak self] step in
///             switch step {
///             case .signedUp:  self?.navigator.next(.finished)   // <- bubble up
///             case .userPressedTermsOfService: self?.toLegal()
///             case .userPressedHaveAccount:    self?.navigationController.popViewController(animated: true)
///             }
///         }
///     }
///
///     private func toLogin() { /* … */ }
///     private func toLegal() { /* … */ }
/// }
///
/// // App-level usage:
/// let appCoord = OnboardingCoordinator(
///     navigationController: NavigationBarLayoutingNavigationController(),
///     api: api
/// )
/// window.rootViewController = appCoord.navigationController
/// appCoord.start()
/// appCoord.navigator.navigation
///     .sink { step in
///         switch step {
///         case .finished: switchToHome()
///         }
///     }
///     .store(in: &globalCancellables)
/// ```
///
/// `@MainActor` because `var navigationController: UINavigationController`
/// (and every push/present/replace helper that operates on it) is
/// main-thread-bound under iOS 26's `@MainActor`-on-UIKit annotations.
@MainActor
public protocol Coordinating: AnyObject {
    /// Sub-flows currently in flight.
    ///
    /// The parent coordinator appends children when starting them and removes
    /// them in ``Coordinating/remove(childCoordinator:)`` once they finish.
    /// Failing to remove a finished child causes a retain-cycle leak through
    /// the navigation pipeline subscriptions — `BaseCoordinator` surfaces this
    /// loudly via ``incorrectImplementation(_:)`` if you try to remove a
    /// child that was never added.
    var childCoordinators: [Coordinating] { get set }

    /// Subscription bag for the navigation pipelines spawned by this
    /// coordinator. Survives for as long as the coordinator does, which keeps
    /// every `viewModel.navigator.navigation.sink { … }` subscription alive
    /// throughout the flow.
    var cancellables: Set<AnyCancellable> { get set }

    /// Builds and presents the coordinator's root scene.
    ///
    /// `BaseCoordinator` traps if this is not overridden by a concrete
    /// subclass — every flow needs a real entry point.
    ///
    /// - Parameter didStart: Optional callback fired after the root scene's
    ///   transition completes. Use it to e.g. record analytics for the flow start.
    func start(didStart: Completion?)

    /// The navigation controller this coordinator operates on.
    ///
    /// Typically a ``NavigationBarLayoutingNavigationController`` so per-scene
    /// nav-bar layouts apply automatically. Coordinators that present modals
    /// take a fresh navigation controller for the modal sub-flow (see
    /// ``Coordinating/presentModalCoordinator(makeCoordinator:didStart:navigationHandler:)``).
    var navigationController: UINavigationController { get }
}
