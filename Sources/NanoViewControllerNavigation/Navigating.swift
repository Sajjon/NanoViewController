// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

/// Type capable of navigating — declares which navigation steps it can emit.
///
/// Conformers expose a typed ``Navigator`` so subscribers (typically a parent
/// coordinator) can react to the steps the conformer emits. The associated
/// ``NavigationStep`` is conventionally a nested `enum` with one case per
/// user-initiated transition.
///
/// Coordinators conform to `Navigating` (via ``BaseCoordinator``) so a parent
/// coordinator can listen to a child coordinator's flow-completion events.
///
/// ViewModels no longer conform to `Navigating` — they expose their
/// navigation channel as part of the value returned from
/// ``ViewModelType/transform(input:)`` (see ``Output``), and the hosting
/// ``SceneController`` re-exposes it for the coordinator to subscribe to.
///
/// ## Example — child coordinator emitting flow-completion steps
///
/// ```swift
/// enum OnboardingFlowStep: Sendable {
///     case finished(User)
///     case userTappedHaveAccount
/// }
///
/// final class OnboardingCoordinator: BaseCoordinator<OnboardingFlowStep> {
///     // BaseCoordinator conforms to Navigating with NavigationStep == OnboardingFlowStep.
///     // It already owns the `navigator: Navigator<OnboardingFlowStep>` property —
///     // we just call .next(...) on it.
///
///     override func start(didStart: Completion? = nil) {
///         showWelcome()
///     }
///
///     private func showWelcome() { /* … navigator.next(.finished(user)) on success … */ }
/// }
/// ```
///
/// `@MainActor` because ``Navigator`` and ``BaseCoordinator`` live on the
/// main actor in this UIKit-based architecture.
@MainActor
public protocol Navigating {
    /// Enum of steps the conformer can emit. Conventionally nested as
    /// `enum YourFlowStep` next to the conforming type. `Sendable` because
    /// navigation pulses flow through
    /// ``Combine/Publisher/sinkOnMain(schedule:_:)`` which dispatches across
    /// a thread boundary; concrete enums of trivial cases are auto-Sendable.
    associatedtype NavigationStep: Sendable

    /// The pulse stream of navigation requests. Conformers call
    /// `navigator.next(.someStep)` to request a transition; subscribers
    /// (parent coordinators) react to those steps.
    var navigator: Navigator<NavigationStep> { get }
}
