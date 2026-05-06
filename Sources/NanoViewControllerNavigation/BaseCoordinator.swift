// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCore
import UIKit

/// Base class for coordinators in NanoViewController.
///
/// Pre-implements every `Coordinating` requirement and adds the typed
/// `navigator: Navigator<NavigationStep>` from ``Navigating``. Subclasses
/// supply only:
///
///   * the navigation step enum (via the generic `NavigationStep` parameter),
///   * any extra dependencies they need (API client, persistence, …),
///   * an override of ``start(didStart:)`` that builds and presents the
///     flow's root scene.
///
/// Everything else — push helpers, modal presentation, replace, child stack
/// management, top-most lookups — comes from extensions on ``Coordinating``
/// in the `Controller` module.
///
/// ## Example — full-flow coordinator
///
/// ```swift
/// import Combine
/// import NanoViewControllerController
/// import NanoViewControllerNavigation
/// import UIKit
///
/// /// What this flow can ask its parent for.
/// enum SignUpFlowStep { case finished(User) }
///
/// final class SignUpCoordinator: BaseCoordinator<SignUpFlowStep> {
///     private let api: API
///
///     init(navigationController: UINavigationController, api: API) {
///         self.api = api
///         super.init(navigationController: navigationController)
///     }
///
///     override func start(didStart: Completion? = nil) {
///         let vm = SignUpViewModel(api: api)
///         push(scene: SignUpScene.self, viewModel: vm) { [weak self] step in
///             guard let self else { return }
///             switch step {
///             case .userPressedHaveAccount:
///                 navigationController.popViewController(animated: true)
///             case .userPressedTermsOfService:
///                 modallyPresent(scene: LegalScene.self, viewModel: LegalViewModel()) { step, dismiss in
///                     switch step {
///                     case .userTappedDone: dismiss(true, nil)
///                     }
///                 }
///             case let .signedUp(user):
///                 // Bubble the result up to the parent (e.g. AppCoordinator).
///                 navigator.next(.finished(user))
///             }
///         }
///         didStart?()
///     }
/// }
///
/// // Parent coordinator wires it up:
/// let signUp = SignUpCoordinator(navigationController: navigationController, api: api)
/// start(coordinator: signUp) { [weak self] step in
///     switch step {
///     case let .finished(user): self?.showHome(for: user)
///     }
/// }
/// ```
///
/// `@MainActor` to match `Coordinating` and `Navigating` — both are
/// main-actor-isolated, so `BaseCoordinator` is too.
@MainActor
open class BaseCoordinator<NavigationStep: Sendable>: Coordinating, Navigating {
    /// Active sub-flows.
    ///
    /// Children are appended on `start(coordinator:...)` and removed in
    /// `remove(childCoordinator:)` once the flow finishes. Use
    /// ``Coordinating/remove(childCoordinator:)`` rather than mutating this
    /// array directly — the helper guards against double-add leaks.
    public var childCoordinators = [Coordinating]()

    /// Stepper that emits typed navigation steps for the parent coordinator.
    ///
    /// Subclasses call `navigator.next(.someStep)` to bubble events up the
    /// coordinator tree. The parent subscribed via
    /// `start(coordinator:...)` receives those steps in its `navigationHandler`.
    public let navigator = Navigator<NavigationStep>()

    /// Subscription bag holding navigation pipelines for the lifetime of the
    /// coordinator. Lives until the coordinator is removed from its parent's
    /// `childCoordinators`.
    public var cancellables = Set<AnyCancellable>()

    /// The `UINavigationController` this coordinator pushes/presents on.
    ///
    /// Typically a ``NavigationBarLayoutingNavigationController``. Modal
    /// sub-flows usually take a *fresh* navigation controller (see
    /// ``Coordinating/presentModalCoordinator(makeCoordinator:didStart:navigationHandler:)``)
    /// so the modal flow has its own back-stack.
    public let navigationController: UINavigationController

    /// Wires the navigation controller this coordinator should drive.
    ///
    /// Subclasses typically extend this initializer to take and store the
    /// dependencies (API client, persistence, etc.) the flow needs.
    ///
    /// - Parameter navigationController: The nav controller this flow
    ///   pushes/presents on. Owned by the parent (or by `UIWindow` for the
    ///   root coordinator).
    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    /// Subclass hook — must build the root scene and present it.
    ///
    /// Crashes via ``abstract`` if a subclass forgets to override; every
    /// concrete coordinator owns the entry point of its flow, so a missing
    /// override means a flow was started but never presented anything.
    ///
    /// - Parameter didStart: Optional callback fired after the root scene
    ///   finishes its presentation transition.
    open func start(didStart _: Completion? = nil) {
        abstract
    }
}
