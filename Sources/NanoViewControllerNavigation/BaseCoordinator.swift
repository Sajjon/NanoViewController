// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import NanoViewControllerCore
import UIKit

/// Base class for our coordinators.
///
/// A *Coordinator* owns navigation logic for one logical flow (e.g. onboarding,
/// settings). It owns the `UINavigationController` it operates on, an array of
/// `childCoordinators` for sub-flows, and a `navigator` that emits typed
/// `NavigationStep`s consumed by the parent coordinator.
///
/// Subclasses must override `start(didStart:)`.
///
/// `@MainActor` to match `Coordinating` (which is main-thread-bound because of
/// `navigationController: UINavigationController`). The `navigator` property is
/// declared `nonisolated` so it can satisfy the non-isolated `Navigating`
/// protocol requirement; that's safe because `Navigator` is `Sendable`.
@MainActor
open class BaseCoordinator<NavigationStep>: Coordinating, Navigating {
    /// Active sub-flows. Children are appended on `start(coordinator:...)` and
    /// removed in `remove(childCoordinator:)` to keep ARC happy.
    public var childCoordinators = [Coordinating]()
    /// Stepper that emits typed navigation steps for the parent coordinator.
    /// `nonisolated` so it satisfies `Navigating`'s non-isolated requirement
    /// even though the enclosing class is `@MainActor`.
    public nonisolated let navigator = Navigator<NavigationStep>()
    /// Subscription bag holding our navigation pipelines for the lifetime of the coordinator.
    public var cancellables = Set<AnyCancellable>()
    /// The `UINavigationController` this coordinator pushes/presents on.
    public let navigationController: UINavigationController

    /// Wires the navigation controller this coordinator should drive.
    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    /// Subclass hook — must build the root scene and present it. Crashes if
    /// not overridden because `BaseCoordinator` itself has no concrete flow.
    open func start(didStart _: Completion? = nil) {
        abstract
    }
}
