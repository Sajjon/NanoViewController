// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// How `Coordinating.start(coordinator:transition:...)` mounts a new child.
///
///   * ``append`` — keep the existing child stack and stack the new one on top.
///     Standard case for nested sub-flows (e.g. onboarding → email-verify).
///   * ``replace`` — empty the current navigation stack first, then start the
///     new child as the only one alive. Use when transitioning between
///     fundamentally different app states (e.g. onboarding finished → main
///     app, or logout → back to onboarding) so the user doesn't briefly see
///     stale flow chrome flash through during the transition.
///
/// ## Example — onboarding hand-off to the main app
///
/// ```swift
/// final class AppCoordinator: BaseCoordinator<Never> {
///     override func start(didStart: Completion? = nil) {
///         showOnboarding()
///     }
///
///     private func showOnboarding() {
///         let onboarding = OnboardingCoordinator(navigationController: navigationController, api: api)
///         start(coordinator: onboarding) { [weak self] step in
///             switch step {
///             case .finished: self?.showMainApp()
///             }
///         }
///     }
///
///     private func showMainApp() {
///         let main = MainCoordinator(navigationController: navigationController, api: api)
///         // .replace wipes the onboarding stack so the user can't swipe back
///         // into a half-torn-down sign-up screen.
///         start(coordinator: main, transition: .replace) { [weak self] step in
///             switch step {
///             case .userLoggedOut: self?.showOnboarding()
///             }
///         }
///     }
/// }
/// ```
public enum CoordinatorTransition {
    /// Append the new child to `childCoordinators` without disturbing existing
    /// children. The standard case for nested sub-flows.
    case append

    /// Replace the entire `childCoordinators` array (and clear the navigation
    /// stack). Used when transitioning between fundamentally different app
    /// states.
    case replace
}
