// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// The central contract every ViewModel conforms to.
///
/// A ViewModel in NanoViewController is a *pure* `Input → Output` transformation:
/// it never holds mutable UI state beyond its `cancellables`, and it produces all
/// of its outputs as Combine publishers. The flow is:
///
/// 1. ``SceneController`` collects `inputFromView` from the root content view.
/// 2. ``SceneController`` builds ``InputFromController`` from its own lifecycle.
/// 3. ``SceneController`` stitches the two into a single `Input` value and calls
///    ``transform(input:)``.
/// 4. The ViewModel returns an `OutputVM` (a struct full of publishers).
/// 5. The view's `populate(with:)` binds those publishers to UI controls.
///
/// ## Why "pure" transform?
///
/// Because all stateful side effects (timers, network calls, navigation pulses)
/// are launched *inside* `transform` and stored in the ViewModel's `cancellables`
/// bag, the ViewModel has no shape that requires mocking lifecycle methods. You
/// can drive it in tests by constructing an `Input` from `PassthroughSubject`s
/// and asserting on the publishers in the returned `OutputVM`.
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
/// /// What the view binds to its UI.
/// struct SignUpOutput {
///     let isSignUpEnabled: AnyPublisher<Bool, Never>
///     let isLoading: AnyPublisher<Bool, Never>
///     let errorMessage: AnyPublisher<String, Never>
/// }
///
/// /// Where the coordinator listens for "what should happen next".
/// enum SignUpStep { case signedUp(User) }
///
/// final class SignUpViewModel: BaseViewModel<SignUpStep, SignUpInputFromView, SignUpOutput> {
///     private let service: SignUpServicing
///     init(service: SignUpServicing) { self.service = service }
///
///     override func transform(input: Input) -> SignUpOutput {
///         let activity = ActivityIndicator()
///         let errors   = ErrorTracker()
///
///         // Validity is just a function of the latest username + password.
///         let credentials = input.fromView.username
///             .combineLatest(input.fromView.password)
///         let isValid = credentials.map { !$0.isEmpty && $1.count >= 8 }
///
///         // On every tap, fire a network call. .switchToLatest() cancels the
///         // previous request if the user double-taps.
///         input.fromView.signUpTapped
///             .withLatestFrom(credentials)
///             .map { [service] u, p in
///                 service.signUp(username: u, password: p)
///                     .trackActivity(activity)
///                     .trackError(errors)
///                     .replaceErrorWithEmpty()
///             }
///             .switchToLatest()
///             .sink { [navigator] user in navigator.next(.signedUp(user)) }
///             .store(in: &cancellables)
///
///         return SignUpOutput(
///             isSignUpEnabled: isValid.eraseToAnyPublisher(),
///             isLoading:       activity.asPublisher(),
///             errorMessage:    errors.asPublisher().map(\.localizedDescription).eraseToAnyPublisher()
///         )
///     }
/// }
/// ```
///
/// The view binds the three output publishers to its controls in
/// `populate(with:)` (see ``ViewModelled``). The coordinator subscribes to
/// `viewModel.navigator.navigation` and routes `.signedUp(user)` to whatever
/// transition makes sense (push the home screen, dismiss the modal, ...).
public protocol ViewModelType {
    /// The combined user-action + controller-lifecycle input the ViewModel consumes.
    ///
    /// Use ``AbstractViewModel/Input`` (the synthesised nested type on every
    /// ``AbstractViewModel`` subclass) — you almost never declare an `Input`
    /// type from scratch.
    associatedtype Input: InputType

    /// The bag of publishers the View binds to UI controls.
    ///
    /// Conventionally a `struct` named `Output` nested inside the concrete
    /// ViewModel, with one publisher per UI control the view drives.
    associatedtype OutputVM

    /// Runs the ViewModel's business logic.
    ///
    /// Called exactly once per instance, typically by ``SceneController`` during
    /// scene construction. Implementations:
    ///
    ///   * Wire `input.fromView` and `input.fromController` publishers into
    ///     business-logic publishers.
    ///   * Subscribe to side-effects (`.sink { … }.store(in: &cancellables)`)
    ///     to trigger navigation, fire toasts, copy to pasteboard, etc.
    ///   * Return an `OutputVM` populated with the publishers the View needs.
    ///
    /// - Parameter input: A pre-stitched `Input` containing both the
    ///   user-driven publishers and the controller-driven publishers.
    /// - Returns: A bag of publishers the View binds to UI controls in
    ///   `populate(with:)`.
    func transform(input: Input) -> OutputVM
}
