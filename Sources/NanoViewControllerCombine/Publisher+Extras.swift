// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import Foundation

// Combine ↔ RxSwift parity helpers. Most are one-liners that wrap stdlib
// Combine operators in shorter, more idiomatic call-sites; `withLatestFrom`
// is a from-scratch implementation since Combine ships nothing equivalent.

// MARK: - replaceErrorWithEmpty

public extension Publisher {
    /// Swallow errors and return an empty (`Never`-failing) publisher.
    ///
    /// Useful at the end of a chain where you've already routed the failure
    /// through ``Combine/Publisher/trackError(_:)`` and just want the error
    /// path to disappear locally so a downstream `sink` doesn't terminate the
    /// stream.
    ///
    /// ## Example
    ///
    /// ```swift
    /// api.fetchHome()
    ///     .trackActivity(activity)
    ///     .trackError(errors)              // errors go to shared tracker
    ///     .replaceErrorWithEmpty()         // chain stays Never-failing
    ///     .sink { home in /* … */ }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// - Returns: A publisher with the same `Output`, but `Failure == Never`.
    func replaceErrorWithEmpty() -> some Publisher<Output, Never> {
        self.catch { _ in Empty<Output, Never>() }
    }
}

// MARK: - mapToVoid

public extension Publisher {
    /// Drops every value's payload, keeping only the *signal*.
    ///
    /// Use when the downstream cares only that a publisher emitted, not what.
    /// Matches RxSwift's `.mapToVoid()`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Map any text-changed event to a "the form changed" pulse.
    /// let formChanged = textField.textPublisher.mapToVoid()
    /// ```
    ///
    /// - Returns: A publisher with the same `Failure`, `Output == Void`.
    func mapToVoid() -> some Publisher<Void, Failure> {
        map { _ in () }
    }
}

// MARK: - filterNil

public extension Publisher {
    /// Filters out `nil` values from a publisher of optionals, narrowing the
    /// output type to `Wrapped`.
    ///
    /// Equivalent to RxSwift's `.filterNil()`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // textPublisher is AnyPublisher<String?, Never>; we want non-nil only.
    /// let text = textField.textPublisher.filterNil()
    /// // text is now Publisher<String, Never>
    /// ```
    ///
    /// - Returns: A publisher of the unwrapped value.
    func filterNil<Wrapped>() -> some Publisher<Wrapped, Failure> where Output == Wrapped? {
        compactMap { $0 }
    }
}

// MARK: - orEmpty (String? → String)

public extension Publisher where Output == String? {
    /// Lifts an optional-string publisher to non-optional by replacing `nil`
    /// with the empty string.
    ///
    /// Used wherever a UI component (text field, label) reports `String?` but
    /// downstream code wants a plain `String`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let username = usernameField.textPublisher.orEmpty
    /// // username is now AnyPublisher<String, Never>
    /// ```
    var orEmpty: AnyPublisher<String, Failure> {
        map { $0 ?? "" }.eraseToAnyPublisher()
    }
}

public extension AnyPublisher where Output == String?, Failure == Never {
    /// `Never`-failure-specialised variant of ``orEmpty`` that returns the
    /// concrete `AnyPublisher<String, Never>` shape used throughout
    /// ``InputFromView`` declarations.
    var orEmpty: AnyPublisher<String, Never> {
        map { $0 ?? "" }.eraseToAnyPublisher()
    }
}

// MARK: - flatMapLatest

public extension Publisher where Failure == Never {
    /// Map to a new publisher and switch to the latest — cancels the previous
    /// inner publisher whenever a new value arrives.
    ///
    /// Equivalent to RxSwift's `.flatMapLatest`. Combine's `flatMap` does *not*
    /// cancel the previous inner publisher, which is the wrong semantics for
    /// "user keeps typing in a search box, only show results for the latest
    /// query".
    ///
    /// ## Example — debounced search
    ///
    /// ```swift
    /// let results = searchField.textPublisher.orEmpty
    ///     .debounce(for: 0.3, scheduler: RunLoop.main)
    ///     .flatMapLatest { [api] query in
    ///         api.search(query)
    ///             .replaceError(with: [])
    ///     }
    /// // Each new keystroke after the debounce window cancels the in-flight
    /// // network call and starts a new one.
    /// ```
    func flatMapLatest<P: Publisher>(
        _ transform: @escaping (Output) -> P
    ) -> some Publisher<P.Output, Never> where P.Failure == Never {
        map(transform).switchToLatest()
    }
}

public extension Publisher {
    /// Failure-preserving variant of ``flatMapLatest(_:)`` — both upstream and
    /// inner publisher must share the same `Failure` type.
    ///
    /// Cancels the in-flight inner publisher whenever a new upstream value
    /// arrives. Use when you need the failure path to surface from inner
    /// publishers (rather than swallowing them).
    ///
    /// ## Example
    ///
    /// ```swift
    /// signUpTap
    ///     .flatMapLatest { [api] _ in api.signUp() }   // throws SignUpError
    ///     .sink(receiveCompletion: { /* surface the error */ },
    ///           receiveValue:      { user in /* … */ })
    ///     .store(in: &cancellables)
    /// ```
    func flatMapLatest<P: Publisher>(
        _ transform: @escaping (Output) -> P
    ) -> some Publisher<P.Output, P.Failure> where P.Failure == Failure {
        map(transform).switchToLatest()
    }
}

// MARK: - withLatestFrom

public extension Publisher where Failure == Never {
    /// On each upstream emission, replace the value with the *latest* value
    /// from `other`.
    ///
    /// Drops upstream events that arrive before `other` has emitted at least
    /// once. RxSwift-equivalent: `.withLatestFrom(other)`.
    ///
    /// ## Example — sample form data on submit
    ///
    /// ```swift
    /// // username/password publishers update continuously; we only care
    /// // about their values *at the moment of tapping submit*.
    /// let credentials = signUpTap.withLatestFrom(
    ///     usernamePublisher.combineLatest(passwordPublisher)
    /// )
    /// credentials
    ///     .flatMapLatest { [api] (u, p) in api.signUp(u, p) }
    ///     .sink { /* … */ }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// - Parameter other: The publisher whose latest value should be sampled.
    /// - Returns: A publisher that emits each `other.Output` whenever
    ///   `self` emits.
    func withLatestFrom<Other: Publisher>(
        _ other: Other
    ) -> some Publisher<Other.Output, Never> where Other.Failure == Never {
        withLatestFrom(other) { $1 }
    }

    /// On each upstream emission, combine its value with the latest value from
    /// `other` using `resultSelector`.
    ///
    /// The trigger is the *upstream* — `other` emissions alone do not produce
    /// output.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Build a request with the latest selected currency on each tap.
    /// let request = sendTap.withLatestFrom(currencyPublisher) { _, currency in
    ///     SendRequest(currency: currency)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - other: The publisher whose latest value should be sampled.
    ///   - resultSelector: Combines the upstream value with `other`'s latest.
    /// - Returns: A publisher emitting the combined result.
    func withLatestFrom<Other: Publisher, Result>(
        _ other: Other,
        resultSelector: @escaping (Output, Other.Output) -> Result
    ) -> some Publisher<Result, Never> where Other.Failure == Never {
        WithLatestFromPublisher(upstream: self, other: other, resultSelector: resultSelector)
    }
}

/// Hand-rolled `Publisher` backing ``Combine/Publisher/withLatestFrom(_:)``.
///
/// Combine doesn't ship `withLatestFrom`, `combineLatest` has the wrong
/// trigger semantics (any source emission produces output, not just the
/// upstream), and `merge` loses pairing. So we inline a small custom
/// publisher with the right semantics.
///
/// See `Sources/Extensions/Combine/Publisher+Extras.swift` in the original
/// Zhip tree for the full design history.
private struct WithLatestFromPublisher<
    Upstream: Publisher,
    Other: Publisher,
    Result
>: Publisher where Upstream.Failure == Never, Other.Failure == Never {
    typealias Output = Result
    typealias Failure = Never

    let upstream: Upstream
    let other: Other
    let resultSelector: (Upstream.Output, Other.Output) -> Result

    func receive<S: Subscriber>(subscriber: S)
        where S.Input == Result, S.Failure == Never
    {
        let subscription = Inner(
            downstream: subscriber,
            other: other,
            resultSelector: resultSelector
        )
        subscriber.receive(subscription: subscription)
        upstream.subscribe(subscription)
    }

    private final class Inner<Downstream: Subscriber>: Subscription, Subscriber
        where Downstream.Input == Result, Downstream.Failure == Never
    {
        typealias Input = Upstream.Output
        typealias Failure = Never

        private var downstream: Downstream?
        private var upstreamSubscription: Subscription?
        private var otherCancellable: AnyCancellable?
        private var latestOther: Other.Output?
        private var pendingDemand: Subscribers.Demand = .none
        private let resultSelector: (Upstream.Output, Other.Output) -> Result

        init(
            downstream: Downstream,
            other: Other,
            resultSelector: @escaping (Upstream.Output, Other.Output) -> Result
        ) {
            self.downstream = downstream
            self.resultSelector = resultSelector
            otherCancellable = other.sink { [weak self] value in
                self?.latestOther = value
            }
        }

        func request(_ demand: Subscribers.Demand) {
            guard demand > .none else { return }
            pendingDemand += demand
            upstreamSubscription?.request(demand)
        }

        func cancel() {
            upstreamSubscription?.cancel()
            upstreamSubscription = nil
            otherCancellable?.cancel()
            otherCancellable = nil
            downstream = nil
            latestOther = nil
            pendingDemand = .none
        }

        func receive(subscription: Subscription) {
            upstreamSubscription = subscription
            if pendingDemand > .none {
                subscription.request(pendingDemand)
            }
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            guard
                let latestOther,
                let downstream
            else {
                return .none
            }
            return downstream.receive(resultSelector(input, latestOther))
        }

        func receive(completion: Subscribers.Completion<Never>) {
            downstream?.receive(completion: completion)
            cancel()
        }
    }
}

// MARK: - ifEmpty(switchTo:)

public extension Publisher where Failure == Never {
    /// Returns a publisher that mirrors `self` *unless* it completes without
    /// ever having emitted, in which case it switches to `replacement`.
    ///
    /// Useful for "fall back to a default when the upstream produces nothing".
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Show a search-suggestions list, OR a "no results" placeholder
    /// // if the search returned nothing.
    /// let suggestions = api.search(query)
    ///     .replaceError(with: [])
    ///     .compactMap { $0.isEmpty ? nil : $0 }
    ///     .ifEmpty(switchTo: AnyPublisher.just([Suggestion.empty]))
    /// ```
    ///
    /// - Parameter replacement: Publisher to switch to if `self` completes empty.
    /// - Returns: A publisher that either mirrors `self` or, if `self`
    ///   completed without emitting, mirrors `replacement` instead.
    func ifEmpty(switchTo replacement: AnyPublisher<Output, Never>) -> some Publisher<Output, Never> {
        Deferred {
            var didEmit = false
            return self.handleEvents(receiveOutput: { _ in didEmit = true })
                .append(
                    Deferred {
                        didEmit ? AnyPublisher<Output, Never>.empty() : replacement
                    }
                )
                .eraseToAnyPublisher()
        }
    }
}
