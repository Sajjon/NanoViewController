// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import Foundation

/// Thread-safe in-flight tracker for asynchronous work.
///
/// Wrap any publisher with the `.trackActivity(_:)` helper (defined below) and the
/// indicator will flip to `true` while the wrapped publisher is subscribed
/// and back to `false` when it emits its first output, completes, or is
/// cancelled. Bind ``asPublisher()`` to a button's "is loading" binder, a
/// `UIRefreshControl`, an activity spinner — anywhere a `Bool` drives a
/// busy-state indicator.
///
/// `ActivityIndicator` is the dual of ``ErrorTracker``: where `ErrorTracker`
/// captures the *failure* path of a chain, `ActivityIndicator` captures the
/// *liveness* path.
///
/// ## Example — show a spinner during a sign-up call
///
/// ```swift
/// import Combine
/// import NanoViewControllerCore
///
/// final class SignUpViewModel: AbstractViewModel<
///     SignUpInputFromView,
///     SignUpViewModel.Publishers,
///     SignUpStep
/// > {
///     override func transform(input: Input) -> Output<Publishers, SignUpStep> {
///         let navigator = Navigator<SignUpStep>()
///         let activity = ActivityIndicator()
///
///         return Output(
///             publishers: Publishers(
///                 // The view binds this Bool to a spinner / disabled state.
///                 isLoading: activity.asPublisher()
///             ),
///             navigation: navigator.navigation
///         ) {
///             // Each tap triggers a network call. trackActivity marks the
///             // indicator true while the call is in flight, then flips back to
///             // false when the call completes (or fails, or is cancelled).
///             input.fromView.signUpTapped
///                 .flatMapLatest { [service] _ in
///                     service.signUp()
///                         .trackActivity(activity)
///                         .replaceErrorWithEmpty()
///                 }
///                 .sink { [navigator] user in navigator.next(.signedUp(user)) }
///         }
///     }
/// }
///
/// // In the view's populate(with:):
/// publishers.isLoading --> primaryButton.isLoadingBinder
/// publishers.isLoading.map { !$0 } --> primaryButton.isEnabledBinder
/// ```
///
/// ## Concurrency
///
/// The internal subject is guarded by an `NSRecursiveLock` so concurrent
/// trackers on background queues can't interleave start/stop calls and leave
/// the indicator stuck in a wrong state. The published values are always
/// delivered serially through the locked subject.
///
public final class ActivityIndicator {
    /// Serializes writes to ``subject`` so concurrent trackers can't interleave
    /// start/stop calls and leave the indicator stuck in a wrong state. Recursive
    /// because `start()` and `stop()` are sometimes called inside `handleEvents`
    /// callbacks that themselves run inside locked sections.
    private let lock = NSRecursiveLock()

    /// The internal backing subject. Exposed read-only as ``asPublisher()``.
    private let subject = CurrentValueSubject<Bool, Never>(false)

    /// Creates an indicator in the "idle" state (`false`).
    public init() {}

    /// Returns a deduplicated publisher suitable for binding to button
    /// spinners / refresh controls / disabled-state UI.
    ///
    /// Idle/active transitions are de-duplicated via `removeDuplicates`, so a
    /// chain of overlapping requests doesn't make the spinner flicker between
    /// `true → true → true …`.
    ///
    /// - Returns: An `AnyPublisher<Bool, Never>` emitting the current loading state.
    public func asPublisher() -> AnyPublisher<Bool, Never> {
        subject.removeDuplicates().eraseToAnyPublisher()
    }
}

private extension ActivityIndicator {
    /// Emits `true` under lock.
    func start() {
        lock.lock(); subject.send(true); lock.unlock()
    }

    /// Emits `false` under lock.
    func stop() {
        lock.lock(); subject.send(false); lock.unlock()
    }

    /// Wraps `source` with start/stop side-effects around its lifecycle.
    /// Called indirectly via the `.trackActivity(_:)` extension below.
    func track<P: Publisher>(_ source: P) -> some Publisher<P.Output, P.Failure> {
        source
            .handleEvents(
                receiveSubscription: { [weak self] _ in self?.start() },
                receiveOutput: { [weak self] _ in self?.stop() },
                receiveCompletion: { [weak self] _ in self?.stop() },
                receiveCancel: { [weak self] in self?.stop() }
            )
    }
}

public extension Publisher {
    /// Tracks this publisher's in-flight state on `indicator`.
    ///
    /// Use the resulting publisher *in place of* the original to get
    /// "spinner-on-while-running" UI for free. The wrapped publisher's
    /// `Output`/`Failure` are unchanged — `trackActivity` only adds
    /// side-effects on the lifecycle events.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let activity = ActivityIndicator()
    ///
    /// let users = api.fetchUsers()
    ///     .trackActivity(activity)         // indicator goes true here
    ///     .replaceError(with: [])
    ///     .eraseToAnyPublisher()           // indicator returns to false on first value
    ///
    /// activity.asPublisher() --> spinner.isVisibleBinder
    /// ```
    ///
    /// - Parameter indicator: The shared indicator to forward lifecycle pulses into.
    /// - Returns: A publisher with the same `Output`/`Failure` as `self`.
    func trackActivity(_ indicator: ActivityIndicator) -> some Publisher<Output, Failure> {
        indicator.track(self)
    }
}
