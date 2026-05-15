// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Foundation

/// The central contract every ViewModel conforms to.
///
/// A ViewModel in NanoViewController is a *pure* `Input → Output<Publishers>`
/// transformation: it holds no mutable subscription state, and it produces all
/// of its outputs as Combine publishers. The flow is:
///
/// 1. ``SceneController`` collects `inputFromView` from the root content view.
/// 2. ``SceneController`` builds ``InputFromController`` from its own lifecycle.
/// 3. ``SceneController`` stitches the two into a single `Input` value and calls
///    ``transform(input:)``.
/// 4. The ViewModel returns an ``Output`` containing the `Publishers` bag and
///    every subscription started inside `transform`.
/// 5. ``SceneController`` retains the cancellables and forwards `publishers`
///    to the view's `populate(with:)`.
///
/// ## Why "pure" transform?
///
/// All stateful side effects (timers, network calls, navigation pulses) are
/// launched *inside* `transform` and returned in the ``Output/cancellables``
/// array. The ViewModel itself has no mutable bag, no lifecycle methods to
/// mock — drive it in tests by constructing an `Input` from
/// `PassthroughSubject`s and asserting on the publishers in the returned
/// ``Output/publishers``.
///
/// ## Example — minimal sign-up ViewModel
///
/// ```swift
/// import Combine
/// import NanoViewControllerCore
/// import NanoViewControllerController     // for InputFromController + BaseViewModel
/// import NanoViewControllerNavigation     // for Navigator
///
/// /// What the user can do on the sign-up screen.
/// struct SignUpInputFromView {
///     let username: AnyPublisher<String, Never>      // text field text
///     let password: AnyPublisher<String, Never>      // text field text
///     let signUpTapped: AnyPublisher<Void, Never>    // primary button tap
/// }
///
/// /// Where the coordinator listens for "what should happen next".
/// enum SignUpStep { case signedUp(User) }
///
/// final class SignUpViewModel: BaseViewModel<SignUpStep, SignUpInputFromView, SignUpViewModel.Publishers> {
///     private let service: SignUpServicing
///     init(service: SignUpServicing) { self.service = service; super.init() }
/// }
///
/// extension SignUpViewModel {
///     /// What the view binds to its UI.
///     struct Publishers {
///         let isSignUpEnabled: AnyPublisher<Bool, Never>
///         let isLoading:       AnyPublisher<Bool, Never>
///         let errorMessage:    AnyPublisher<String, Never>
///     }
/// }
///
/// extension SignUpViewModel {
///     override func transform(input: Input) -> Output<Publishers> {
///         let activity = ActivityIndicator()
///         let errors   = ErrorTracker()
///
///         let credentials = input.fromView.username.combineLatest(input.fromView.password)
///         let isValid = credentials.map { !$0.isEmpty && $1.count >= 8 }
///
///         return Output(
///             publishers: Publishers(
///                 isSignUpEnabled: isValid.eraseToAnyPublisher(),
///                 isLoading:       activity.asPublisher(),
///                 errorMessage:    errors.asPublisher().map(\.localizedDescription).eraseToAnyPublisher()
///             )
///         ) {
///             input.fromView.signUpTapped
///                 .withLatestFrom(credentials)
///                 .map { [service] u, p in
///                     service.signUp(username: u, password: p)
///                         .trackActivity(activity)
///                         .trackError(errors)
///                         .replaceErrorWithEmpty()
///                 }
///                 .switchToLatest()
///                 .sink { [navigator] user in navigator.next(.signedUp(user)) }
///         }
///     }
/// }
/// ```
///
/// The view binds the three publishers in `populate(with:)` (see
/// ``ViewModelled``). The coordinator subscribes to
/// `viewModel.navigator.navigation` and routes `.signedUp(user)` to whatever
/// transition makes sense.
///
/// `@MainActor` because every concrete ViewModel is constructed by, observed
/// from, and torn down with a `SceneController` (a `UIViewController`
/// subclass), all of which run on the main actor.
@MainActor
public protocol ViewModelType {
    /// The combined user-action + controller-lifecycle input the ViewModel consumes.
    ///
    /// Use ``AbstractViewModel/Input`` (the synthesised nested type on every
    /// ``AbstractViewModel`` subclass) — you almost never declare an `Input`
    /// type from scratch.
    associatedtype Input: InputType

    /// The publisher bag the view binds to UI controls.
    ///
    /// Conventionally a `struct` named `Publishers` nested inside the
    /// concrete ViewModel, with one publisher per UI control the view drives.
    associatedtype Publishers

    /// Runs the ViewModel's business logic.
    ///
    /// Called exactly once per instance, typically by ``SceneController``
    /// during scene construction. Implementations:
    ///
    ///   * Wire `input.fromView` and `input.fromController` publishers into
    ///     business-logic publishers.
    ///   * Return an ``Output`` whose `publishers:` field holds the
    ///     ``Publishers`` value and whose `subscriptions:` builder block
    ///     contains every side-effect `.sink { … }` the view-model starts.
    ///
    /// - Parameter input: A pre-stitched `Input` containing both the
    ///   user-driven publishers and the controller-driven publishers.
    /// - Returns: An ``Output`` wrapping the publisher bag and the
    ///   subscriptions started inside `transform`.
    func transform(input: Input) -> Output<Publishers>
}
