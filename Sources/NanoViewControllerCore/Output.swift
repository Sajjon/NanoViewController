// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine

/// What every ViewModel's ``ViewModelType/transform(input:)`` returns: the
/// `Publishers` bag the view binds to UI controls, plus the `[AnyCancellable]`
/// the controller retains for the lifetime of the scene.
///
/// `Output` is the *wrapper*; the generic `Publishers` parameter is the
/// ViewModel-specific publisher-bundle the view consumes in `populate(with:)`.
/// Folding both into one value moves subscription ownership out of the
/// ViewModel — ``AbstractViewModel`` no longer carries a `cancellables` bag.
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
/// override func transform(input: Input) -> Output<Publishers> {
///     let activity = ActivityIndicator()
///     let isLoading = activity.asPublisher()
///     let isSubmitEnabled = …
///
///     return Output(
///         publishers: Publishers(
///             isSubmitEnabled: isSubmitEnabled,
///             isLoading: isLoading
///         )
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
public struct Output<Publishers> {
    /// The publisher bag the view binds to UI controls via ``ViewModelled/populate(with:)``.
    public let publishers: Publishers

    /// Subscriptions started inside `transform` that must outlive the call.
    /// ``SceneController`` stores these in its own bag so they live as long
    /// as the scene.
    public let cancellables: [AnyCancellable]

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - publishers: The publisher bag the view binds.
    ///   - subscriptions: A `@BindingsBuilder` block whose statements are
    ///     each an `AnyCancellable` (`.sink { … }`, helpers, etc.). Defaults
    ///     to an empty block for ViewModels that need no side-effect
    ///     subscriptions.
    public init(
        publishers: Publishers,
        @BindingsBuilder subscriptions: () -> [AnyCancellable] = { [] }
    ) {
        self.publishers = publishers
        self.cancellables = subscriptions()
    }
}
