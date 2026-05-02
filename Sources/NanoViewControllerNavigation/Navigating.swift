// MIT License — Copyright (c) 2018-2026 Open Zesame

/// Type capable of navigating — declares which navigation steps it can emit.
///
/// Conformers expose a typed ``Navigator`` so subscribers (typically
/// coordinators) can react to the steps the conformer emits. The associated
/// ``NavigationStep`` is conventionally a nested `enum` with one case per
/// user-initiated transition the screen can request.
///
/// Both ViewModels (via ``BaseViewModel``) and Coordinators (via
/// ``BaseCoordinator``) conform to `Navigating` — the former so a
/// ``SceneController``-backed scene can declare "what should happen next" in a
/// View-agnostic way, the latter so a parent coordinator can listen to a child
/// coordinator's flow-completion events.
///
/// ## Example — defining a screen's navigation contract
///
/// ```swift
/// import NanoViewControllerNavigation
///
/// /// Three things the user can do on the SignUp screen.
/// enum SignUpUserAction {
///     case userPressedHaveAccount         // → coordinator pops back to login
///     case userPressedTermsOfService      // → coordinator presents legal modal
///     case signedUp(User)                 // → coordinator switches to home
/// }
///
/// final class SignUpViewModel:
///     BaseViewModel<SignUpUserAction, SignUpInputFromView, SignUpOutput>
/// {
///     // BaseViewModel conforms to Navigating with NavigationStep == SignUpUserAction.
///     // It already has the `navigator: Navigator<SignUpUserAction>` property —
///     // we just call .next(...) on it.
///
///     override func transform(input: Input) -> SignUpOutput {
///         input.fromView.haveAccountTap
///             .sink { [navigator] in navigator.next(.userPressedHaveAccount) }
///             .store(in: &cancellables)
///         // …
///     }
/// }
/// ```
///
/// On the coordinator side,
/// ``Coordinating/push(scene:viewModel:animated:navigationPresentationCompletion:navigationHandler:)``
/// (and the modal/replace overloads) take a `navigationHandler` closure that
/// receives every emitted ``NavigationStep`` so you can pattern-match on the
/// enum and route each case to the right transition.
public protocol Navigating {
    /// Enum of steps the conformer can emit. Conventionally nested as
    /// `enum YourSceneStep` next to the conforming type.
    associatedtype NavigationStep

    /// The pulse stream of navigation requests. ViewModels call
    /// `navigator.next(.someStep)` to request a transition; subscribers
    /// (coordinators) react to those steps.
    var navigator: Navigator<NavigationStep> { get }
}
