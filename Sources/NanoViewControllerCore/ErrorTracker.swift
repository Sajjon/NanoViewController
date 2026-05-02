// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import Foundation

/// Shared sink that captures errors from arbitrary publishers and re-publishes
/// them as a `Never`-failing stream.
///
/// `ErrorTracker` is the dual of ``ActivityIndicator`` for the error path:
///
///   * Wrap a publisher with ``Combine/Publisher/trackError(_:)`` to forward
///     any failure into the tracker without altering the upstream's
///     `Output`/`Failure` types.
///   * Subscribe to ``asPublisher()`` for a `Never`-failing stream of every
///     error captured by the tracker — perfect for binding to validation
///     labels or a single shared toast subject.
///
/// One tracker per ViewModel is the typical pattern: every chain (login call,
/// fetch, upload) routes its errors into the same tracker, and the View binds
/// the tracker's stream once.
///
/// ## Example — global error toast plus per-chain typed handling
///
/// ```swift
/// final class HomeViewModel: BaseViewModel<HomeStep, HomeInputFromView, HomeOutput> {
///     override func transform(input: Input) -> HomeOutput {
///         let activity = ActivityIndicator()
///         let errors   = ErrorTracker()
///
///         let initialFetch = input.fromController.viewWillAppear.first()
///             .flatMapLatest { [api] _ in
///                 api.fetchHome()
///                     .trackActivity(activity)
///                     .trackError(errors)              // <- forwards failures
///                     .replaceErrorWithEmpty()         // <- drops them locally
///             }
///
///         let userRefresh = input.fromView.pullToRefresh
///             .flatMapLatest { [api] _ in
///                 api.fetchHome()
///                     .trackActivity(activity)
///                     .trackError(errors)              // <- same shared tracker
///                     .replaceErrorWithEmpty()
///             }
///
///         // Every captured error becomes a toast.
///         errors.asPublisher()
///             .map { Toast($0.localizedDescription) }
///             .sink { input.fromController.toastSubject.send($0) }
///             .store(in: &cancellables)
///
///         // Or use the typed projection for a typed-error case.
///         let validationMessage = errors.compactMap { ($0 as? ValidationError)?.message }
///
///         return HomeOutput(
///             items:    Publishers.Merge(initialFetch, userRefresh).map(\.items).eraseToAnyPublisher(),
///             isLoading: activity.asPublisher(),
///             validationMessage: validationMessage
///         )
///     }
/// }
/// ```
///
/// Combine's `replaceError` family already turns a failing publisher into a
/// `Never`-failing one; `ErrorTracker` is what you reach for when several
/// chains need to share one error sink.
public final class ErrorTracker {
    /// Internal subject that captured errors are pushed into.
    ///
    /// Exposed indirectly: ``asPublisher()`` returns the full untyped stream,
    /// ``compactMap(_:)`` returns a typed projection. Sibling packages (e.g.
    /// a Validation module) layer typed-error projections through
    /// `compactMap(_:)` without touching the raw subject.
    private let subject = PassthroughSubject<Error, Never>()

    /// Creates an empty tracker.
    public init() {}

    /// The full stream of captured errors as a `Never`-failing publisher.
    ///
    /// Bind this to a global toast / banner sink to surface every error
    /// without per-call wiring.
    ///
    /// - Returns: An `AnyPublisher<Error, Never>` of every error tracked.
    public func asPublisher() -> AnyPublisher<Error, Never> {
        subject.eraseToAnyPublisher()
    }

    /// Wraps `source` so each `.failure` completion is forwarded into this
    /// tracker.
    ///
    /// The returned publisher preserves `source`'s `Output`/`Failure` shape —
    /// handy as a transparent middle stage in a chain. Pair with
    /// `replaceErrorWithEmpty()` (or `replaceError(with:)`) downstream if you
    /// want to silence the failure path locally after tracking it.
    ///
    /// - Parameter source: The upstream publisher whose failures should be tracked.
    /// - Returns: A publisher with the same `Output`/`Failure` as `source`.
    public func track<P: Publisher>(from source: P) -> some Publisher<P.Output, P.Failure>
        where P.Failure: Error
    {
        source
            .handleEvents(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.subject.send(error)
                }
            })
    }

    /// Internal hook used by sibling packages (e.g. a Validation module) to
    /// project captured errors through a typed `compactMap` without exposing
    /// the raw subject.
    ///
    /// The closure receives every tracked error and returns the projected
    /// value — `nil` results are dropped. The returned publisher is
    /// `Never`-failing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Project just the validation errors out of a generic ErrorTracker.
    /// let validationMessages = errors.compactMap { error -> String? in
    ///     guard let v = error as? ValidationError else { return nil }
    ///     return v.localizedMessage
    /// }
    /// validationMessages --> errorLabel.textBinder
    /// ```
    ///
    /// - Parameter transform: A closure that converts an error to the
    ///   projected type, returning `nil` to skip.
    /// - Returns: An `AnyPublisher<T, Never>` of the projected values.
    public func compactMap<T>(_ transform: @escaping (Swift.Error) -> T?) -> AnyPublisher<T, Never> {
        subject
            .compactMap(transform)
            .eraseToAnyPublisher()
    }
}

public extension Publisher {
    /// Threads any failure of this publisher through `tracker` without altering
    /// the upstream's `Output`/`Failure` types.
    ///
    /// The standard call-site form for capturing errors at a use-case
    /// boundary. Pair with `replaceErrorWithEmpty()` if you also want to
    /// silence the local error path.
    ///
    /// ## Example
    ///
    /// ```swift
    /// api.uploadAvatar(image)
    ///     .trackActivity(activity)
    ///     .trackError(errors)              // shared tracker
    ///     .replaceErrorWithEmpty()         // local chain stays Never-failing
    ///     .sink { [navigator] in navigator.next(.uploaded) }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// - Parameter tracker: The `ErrorTracker` to forward failures into.
    /// - Returns: A publisher with the same `Output`/`Failure` as `self`.
    func trackError(_ tracker: ErrorTracker) -> some Publisher<Output, Failure>
        where Failure: Error
    {
        tracker.track(from: self)
    }
}
