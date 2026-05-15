// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine

/// What every ViewModel's ``ViewModelType/transform(input:)`` returns: the
/// `Publishers` bag the view binds to UI controls, the navigation publisher
/// the coordinator subscribes to, and the `[AnyCancellable]` the controller
/// retains for the lifetime of the scene.
///
/// `Output` is the *wrapper*; the generic `Publishers` parameter is the
/// ViewModel-specific publisher-bundle the view consumes in `populate(with:)`,
/// and `NavigationStep` is the enum the coordinator pattern-matches on.
/// Folding all three into one value moves both subscription ownership and
/// navigation out of the ViewModel — the ViewModel itself carries no stored
/// state.
///
/// ## Example — at the call site
///
/// ```swift
/// public extension SignUpViewModel {
///     struct Publishers {
///         let isSubmitEnabled: AnyPublisher<Bool, Never>
///         let isLoading:       AnyPublisher<Bool, Never>
///     }
/// }
///
/// override func transform(input: Input) -> Output<Publishers, SignUpStep> {
///     let navigator = Navigator<SignUpStep>()
///     let activity = ActivityIndicator()
///     let isLoading = activity.asPublisher()
///     let isSubmitEnabled = …
///
///     return Output(
///         publishers: Publishers(
///             isSubmitEnabled: isSubmitEnabled,
///             isLoading: isLoading
///         ),
///         navigation: navigator.navigation
///     ) {
///         input.fromView.submitTrigger
///             .map { [service] in service.signUp(…).trackActivity(activity) }
///             .switchToLatest()
///             .sink { [navigator] user in navigator.next(.signedUp(user)) }
///     }
/// }
/// ```
///
/// The trailing closure is `@BindingsBuilder`-annotated, so each `.sink { … }`
/// is a statement, not an array element — no `.store(in: &cancellables)` and
/// no `[a, b, c]` collection. Helpers that return `[AnyCancellable]` plug in
/// directly. `if` / `switch` / `for` work naturally.
///
/// ## Late navigation subscription
///
/// The coordinator subscribes to ``navigation`` *after* `transform` returns
/// (it can't subscribe sooner — the publisher doesn't exist yet). In practice
/// this is identical to the prior `viewModel.navigator.navigation` flow,
/// which was also subscribed-to after the scene's `bindViewToViewModel`
/// triggered `transform`. The only constraint: `transform` must not emit
/// navigation **synchronously during construction** (e.g. `Just(.x).sink { … }`
/// — that step would be dropped). Real flows emit on user input, which can't
/// fire before the coordinator finishes wiring.
///
/// ## Naming note — `Publishers` collides with `Combine.Publishers`
///
/// The consumer's nested struct is conventionally called `Publishers` (this
/// shape is plain "a bag of `AnyPublisher`s"). Combine exports a top-level
/// enum of the same name (`Combine.Publishers.Map`, `…CombineLatest`, …).
/// Bare unqualified `Publishers(…)` inside the ViewModel resolves to the
/// nested type — which is what consumers want at the construction site. Code
/// that explicitly reaches into Combine's namespace can qualify as
/// `Combine.Publishers.X`.
@MainActor
public struct Output<Publishers, NavigationStep: Sendable> {
    /// The publisher bag the view binds to UI controls via ``ViewModelled/populate(with:)``.
    public let publishers: Publishers

    /// The navigation step stream the coordinator subscribes to. The
    /// ViewModel emits via a locally-owned `PassthroughSubject` (or a
    /// ``Navigator``) — the coordinator pattern-matches on the cases.
    public let navigation: AnyPublisher<NavigationStep, Never>

    /// Subscriptions started inside `transform` that must outlive the call.
    /// ``SceneController`` stores these in its own bag so they live as long
    /// as the scene.
    public let cancellables: [AnyCancellable]

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - publishers: The publisher bag the view binds.
    ///   - navigation: The navigation step stream. Pass `Empty()…` (or use
    ///     the `NavigationStep == Never` overload) if the scene emits no
    ///     navigation.
    ///   - subscriptions: A `@BindingsBuilder` block whose statements are
    ///     each an `AnyCancellable` (`.sink { … }`, helpers, etc.). Defaults
    ///     to an empty block for ViewModels that need no side-effect
    ///     subscriptions.
    public init(
        publishers: Publishers,
        navigation: AnyPublisher<NavigationStep, Never>,
        @BindingsBuilder subscriptions: () -> [AnyCancellable] = { [] }
    ) {
        self.publishers = publishers
        self.navigation = navigation
        self.cancellables = subscriptions()
    }
}

public extension Output where NavigationStep == Never {
    /// Convenience initialiser for scenes that emit no navigation. The
    /// navigation channel is wired to `Empty()` so the coordinator's
    /// subscription is a no-op for the scene's lifetime.
    init(
        publishers: Publishers,
        @BindingsBuilder subscriptions: () -> [AnyCancellable] = { [] }
    ) {
        self.publishers = publishers
        self.navigation = Empty().eraseToAnyPublisher()
        self.cancellables = subscriptions()
    }
}
