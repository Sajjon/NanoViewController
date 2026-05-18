// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import Foundation

/// One-way bridge between ViewModels (which decide *what* happens next) and
/// coordinators (which know *how* to push/pop/present).
///
/// A ``Navigator`` is a thin wrapper around a `PassthroughSubject`:
///
///   * The ViewModel calls ``next(_:)`` to declare a navigation intent.
///   * The Coordinator subscribes to ``navigation`` to receive those intents
///     and perform the actual UIKit transitions.
///
/// Because the type is generic over `NavigationStep`, both sides share a
/// strongly-typed contract: ViewModels can only emit cases they declare, and
/// coordinators get exhaustive `switch` checking on the navigation handler.
///
/// ## Example — paired ViewModel + Coordinator
///
/// ```swift
/// // 1. ViewModel side — declare the steps and emit them.
/// enum SignUpStep {
///     case signedUp(User)
///     case userPressedHaveAccount
/// }
///
/// final class SignUpViewModel: AbstractViewModel<
///     SignUpInputFromView, SignUpViewModel.Publishers, SignUpStep
/// > {
///     override func transform(input: Input) -> Output<Publishers, SignUpStep> {
///         let navigator = Navigator<SignUpStep>()
///         return Output(
///             publishers: Publishers(/* … */),
///             navigation: navigator.navigation
///         ) {
///             input.fromView.haveAccountTap
///                 .sink { [navigator] in navigator.next(.userPressedHaveAccount) }
///
///             input.fromView.signUpTap
///                 .flatMapLatest { [api] _ in api.signUp().replaceErrorWithEmpty() }
///                 .sink { [navigator] user in navigator.next(.signedUp(user)) }
///         }
///     }
/// }
///
/// // 2. Coordinator side — subscribe and route.
/// final class OnboardingCoordinator: BaseCoordinator<Never> {
///     override func start(didStart: Completion? = nil) {
///         let vm = SignUpViewModel(api: api)
///         push(scene: SignUpScene.self, viewModel: vm) { [weak self] step in
///             switch step {
///             case .userPressedHaveAccount:
///                 self?.navigationController.popViewController(animated: true)
///             case let .signedUp(user):
///                 self?.showHome(for: user)
///             }
///         }
///     }
/// }
/// ```
/// `@MainActor` because the property `navigation` (a `PassthroughSubject`-
/// backed publisher) is consumed by coordinators on the main thread in this
/// UIKit-based architecture.
///
/// `@unchecked Sendable` because `PassthroughSubject` itself does not yet
/// conform to `Sendable` (Apple's Combine has not been audited for Swift 6
/// strict concurrency). The unchecked claim is safe here because:
///
///   * Every `send` on `navigationSubject` goes through ``next(_:)``, which
///     guarantees the send happens on the main actor (synchronously when
///     already on main, via `Task { @MainActor in … }` otherwise).
///   * The lazy `navigation` accessor is `@MainActor`-isolated, so all
///     reads (subscription registration, demand requests) originate on
///     main.
///   * Combine's own subscription / cancellation / demand bookkeeping on
///     `PassthroughSubject` is documented thread-safe, so even if a sink
///     stored in a `@MainActor` `cancellables` bag is torn down off-main
///     (`AnyCancellable.deinit` from a non-main context), the resulting
///     internal mutation doesn't race with our `send`s.
///
/// Remove `@unchecked` when Combine's `PassthroughSubject` gains native
/// `Sendable` conformance.
@MainActor
public final class Navigator<NavigationStep>: @unchecked Sendable {
    /// Internal backing subject. Exposed read-only via ``navigation``. All
    /// `send` calls go through ``next(_:)``, which guarantees the send
    /// happens on the main actor; subscription / cancellation / demand
    /// bookkeeping is thread-safe on `PassthroughSubject` itself.
    private let navigationSubject = PassthroughSubject<NavigationStep, Never>()

    /// Erased publisher coordinators subscribe to.
    ///
    /// Lazy so each `Navigator` produces the publisher at most once, and any
    /// subsequent reads of `navigation` share the same erased publisher
    /// instance — important when a tested coordinator reads it multiple times
    /// (assertions + the actual subscription).
    public lazy var navigation: AnyPublisher<NavigationStep, Never> = navigationSubject.eraseToAnyPublisher()

    /// Default initializer.
    public init() {}
}

public extension Navigator where NavigationStep: Sendable {
    /// Emits `step` on ``navigation``.
    ///
    /// Called by ViewModels to declare a navigation intent. The Navigator does
    /// no work itself — the connected coordinator decides how to satisfy the
    /// intent (push, pop, present, finish flow).
    ///
    /// `nonisolated` so it is safe to call from any actor context — including
    /// `Combine.sink` closures that resume on the cooperative thread pool
    /// after `await`-ing an async use case (e.g. a Zesame `Future` whose
    /// `Task { … promise(.success(value)) }` does not preserve caller
    /// isolation). When called off-main the actual subject send is hopped
    /// to the main actor, so coordinator subscribers always receive on
    /// main. When already on main the fast path avoids the unnecessary
    /// `Task { @MainActor in … }` hop.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Inside a ViewModel's transform(input:):
    /// input.fromView.continueTapped
    ///     .sink { [navigator] in navigator.next(.userPressedContinue) }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// - Parameter step: The navigation step to emit.
    nonisolated func next(_ step: NavigationStep) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { navigationSubject.send(step) }
        } else {
            Task { @MainActor in navigationSubject.send(step) }
        }
    }
}
