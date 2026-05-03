// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine

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
/// final class SignUpViewModel: BaseViewModel<SignUpStep, SignUpInputFromView, SignUpOutput> {
///     override func transform(input: Input) -> SignUpOutput {
///         input.fromView.haveAccountTap
///             .sink { [navigator] in navigator.next(.userPressedHaveAccount) }
///             .store(in: &cancellables)
///
///         input.fromView.signUpTap
///             .flatMapLatest { [api] _ in api.signUp().replaceErrorWithEmpty() }
///             .sink { [navigator] user in navigator.next(.signedUp(user)) }
///             .store(in: &cancellables)
///         // …
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
/// `@MainActor` because both producers (view-models calling ``next(_:)``)
/// and consumers (coordinators sinking on ``navigation``) run on the main
/// thread in this UIKit-based architecture.
@MainActor
public final class Navigator<NavigationStep> {
    /// Internal backing subject. Exposed read-only via ``navigation``.
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

public extension Navigator {
    /// Emits `step` on ``navigation``.
    ///
    /// Called by ViewModels to declare a navigation intent. The Navigator does
    /// no work itself — the connected coordinator decides how to satisfy the
    /// intent (push, pop, present, finish flow).
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
    func next(_ step: NavigationStep) {
        navigationSubject.send(step)
    }
}
