// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import Foundation
import NanoViewControllerCore

/// Abstract base class supplying the boilerplate every concrete scene-bound
/// ViewModel needs.
///
/// `AbstractViewModel` provides:
///
///   * a synthesised nested ``Input`` struct conforming to ``InputType`` whose
///     controller channel is pinned to ``InputFromController``, and
///   * an open `transform(input:)` method that traps if not overridden — so
///     forgetting to override surfaces immediately at runtime.
///
/// Subscriptions started inside `transform`, plus the navigation publisher,
/// are returned in the resulting ``Output`` and consumed by
/// ``SceneController`` for the lifetime of the scene — `AbstractViewModel`
/// does **not** carry a `cancellables` bag or a stored `navigator`.
///
/// The class is generic over three slots:
///
///   * `FromView` — the view-driven publisher struct the View exposes.
///   * `Publishers` — the publisher bag returned to the view.
///   * `NavigationStep` — the enum of navigation transitions; use `Never`
///     for scenes that emit none.
///
/// The controller channel is pinned to ``InputFromController`` (by the
/// ``InputType`` protocol itself) — every scene-bound view-model uses it.
/// View-models that don't run on a ``SceneController`` (embedded sub-views,
/// for example) should conform to ``ViewModelType`` directly without
/// subclassing `AbstractViewModel`.
///
/// ## Example — a sign-up ViewModel with navigation
///
/// ```swift
/// import Combine
/// import NanoViewControllerController
/// import NanoViewControllerCore
/// import NanoViewControllerNavigation
///
/// enum SignUpStep: Sendable { case signedUp(User) }
///
/// struct SignUpInputFromView {
///     let username:     AnyPublisher<String, Never>
///     let password:     AnyPublisher<String, Never>
///     let signUpTapped: AnyPublisher<Void, Never>
/// }
///
/// final class SignUpViewModel: AbstractViewModel<
///     SignUpInputFromView,
///     SignUpViewModel.Publishers,
///     SignUpStep
/// > {
///     private let service: SignUpServicing
///     init(service: SignUpServicing) { self.service = service; super.init() }
/// }
///
/// extension SignUpViewModel {
///     struct Publishers {
///         let isSignUpEnabled: AnyPublisher<Bool, Never>
///         let isLoading:       AnyPublisher<Bool, Never>
///     }
/// }
///
/// extension SignUpViewModel {
///     override func transform(input: Input) -> Output<Publishers, SignUpStep> {
///         let navigator = Navigator<SignUpStep>()
///         let activity  = ActivityIndicator()
///
///         let credentials = input.fromView.username.combineLatest(input.fromView.password)
///         let isValid = credentials.map { !$0.isEmpty && $1.count >= 8 }
///
///         return Output(
///             publishers: Publishers(
///                 isSignUpEnabled: isValid.eraseToAnyPublisher(),
///                 isLoading:       activity.asPublisher()
///             ),
///             navigation: navigator.navigation
///         ) {
///             input.fromView.signUpTapped
///                 .withLatestFrom(credentials)
///                 .map { [service] u, p in
///                     service.signUp(username: u, password: p).trackActivity(activity)
///                 }
///                 .switchToLatest()
///                 .sink { [navigator] user in navigator.next(.signedUp(user)) }
///         }
///     }
/// }
/// ```
///
/// `@MainActor` because it conforms to ``ViewModelType``, which is itself
/// `@MainActor`. View-models in this package are inherently main-thread —
/// they're owned by `SceneController` (a `UIViewController` subclass) and
/// their `transform(input:)` runs on the main actor.
@MainActor
open class AbstractViewModel<
    FromView,
    Publishers,
    NavigationStep: Sendable
>: ViewModelType {
    /// The concrete ``InputType`` Swift synthesizes for each
    /// `AbstractViewModel` specialisation.
    ///
    /// `SceneController` constructs this struct by combining the View's
    /// `inputFromView` with the lifecycle-derived ``InputFromController`` it
    /// owns, and hands it to ``transform(input:)``.
    public struct Input: InputType {
        /// Controller-lifecycle + write-back subjects channel.
        public let fromController: InputFromController

        /// User-driven publishers channel (taps, text, toggles).
        public let fromView: FromView

        /// Designated initializer.
        ///
        /// `SceneController` calls this to stitch together the two input
        /// channels before handing the struct to `transform`. Tests call it
        /// directly when building synthetic input.
        public init(fromView: FromView, fromController: InputFromController) {
            self.fromView = fromView
            self.fromController = fromController
        }
    }

    /// Designated initialiser — public so consumer subclasses can call `super.init()`.
    public init() {}

    /// Runs the ViewModel's business logic — must be overridden by subclasses.
    ///
    /// The default implementation traps via the ``abstract`` helper to surface
    /// a missing override at runtime instead of silently returning a default
    /// value (which would break scene wiring further down the line).
    ///
    /// - Parameter input: The pre-stitched ``Input`` with both channels.
    /// - Returns: An ``Output`` wrapping the publisher bag, the navigation
    ///   publisher, and the subscriptions started inside `transform`.
    open func transform(input _: Input) -> Output<Publishers, NavigationStep> {
        abstract
    }
}
