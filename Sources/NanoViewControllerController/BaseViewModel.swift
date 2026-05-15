// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import NanoViewControllerCore
import NanoViewControllerNavigation

/// Concrete convenience over ``AbstractViewModel`` that pins `FromController`
/// to the package's standard ``InputFromController`` and adds a typed
/// ``Navigator``.
///
/// This is the base class most concrete view-models in consuming apps should
/// subclass. Generic parameters:
///
///   * `NavigationStep` — the per-scene navigation enum the coordinator
///     listens for (e.g. `enum SignUpUserAction { case signedUp(User) }`).
///   * `InputFromView` — the view-event channel struct nested inside the
///     subclass (taps, text changes, toggles).
///   * `Publishers` — the bag of publishers the view binds to UI controls.
///
/// `AbstractViewModel` stays generic over `FromController` so consumers who
/// want a different controller-input shape can still use it directly. Use
/// this class otherwise — it's what 99% of scenes need.
///
/// ## Example — sign-up screen ViewModel
///
/// ```swift
/// import Combine
/// import NanoViewControllerController
/// import NanoViewControllerCore
/// import NanoViewControllerNavigation
///
/// // 1. Define the navigation contract.
/// enum SignUpStep {
///     case signedUp(User)
///     case userPressedHaveAccount
///     case userPressedTermsOfService
/// }
///
/// // 2. Define the view-event channel (struct of publishers).
/// struct SignUpInputFromView {
///     let username:               AnyPublisher<String, Never>
///     let password:               AnyPublisher<String, Never>
///     let userPressedSignUp:      AnyPublisher<Void, Never>
///     let userPressedHaveAccount: AnyPublisher<Void, Never>
///     let userPressedTermsOfService: AnyPublisher<Void, Never>
/// }
///
/// // 3. The ViewModel itself — subclass BaseViewModel.
/// final class SignUpViewModel: BaseViewModel<SignUpStep, SignUpInputFromView, SignUpViewModel.Publishers> {
///     private let service: SignUpServicing
///
///     init(service: SignUpServicing) { self.service = service; super.init() }
/// }
///
/// // 4. Declare the publisher bag the view binds to.
/// extension SignUpViewModel {
///     struct Publishers {
///         let isSignUpEnabled: AnyPublisher<Bool, Never>
///         let isLoading:       AnyPublisher<Bool, Never>
///     }
/// }
///
/// // 5. Implement transform.
/// extension SignUpViewModel {
///     override func transform(input: Input) -> Output<Publishers> {
///         let activity = ActivityIndicator()
///
///         let credentials = input.fromView.username.combineLatest(input.fromView.password)
///         let isValid = credentials.map { !$0.isEmpty && $1.count >= 8 }
///
///         return Output(
///             publishers: Publishers(
///                 isSignUpEnabled: isValid.eraseToAnyPublisher(),
///                 isLoading:       activity.asPublisher()
///             )
///         ) {
///             input.fromView.userPressedSignUp
///                 .withLatestFrom(credentials)
///                 .map { [service] u, p in
///                     service.signUp(username: u, password: p)
///                         .trackActivity(activity)
///                         .replaceErrorWithEmpty()
///                 }
///                 .switchToLatest()
///                 .sink { [navigator] user in navigator.next(.signedUp(user)) }
///
///             input.fromView.userPressedHaveAccount
///                 .sink { [navigator] in navigator.next(.userPressedHaveAccount) }
///
///             input.fromView.userPressedTermsOfService
///                 .sink { [navigator] in navigator.next(.userPressedTermsOfService) }
///         }
///     }
/// }
/// ```
///
/// The coordinator subscribes to `signUpVM.navigator.navigation` and routes
/// each `SignUpStep` to a push/present/finish — see ``BaseCoordinator`` for
/// that side of the wiring.
open class BaseViewModel<NavigationStep: Sendable, InputFromView, Publishers>:
    AbstractViewModel<InputFromView, InputFromController, Publishers>,
    Navigating
{
    /// Stepper the coordinator subscribes to.
    ///
    /// Subclasses call `navigator.next(.step)` to declare an intent; the
    /// coordinator decides how to satisfy it (push, pop, present, finish).
    public let navigator = Navigator<NavigationStep>()
}
