// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import UIKit

// MARK: - sinkOnMain

public extension Publisher where Failure == Never {
    /// Subscribes and dispatches each value to a `@MainActor` closure.
    ///
    /// In production the default `DispatchQueue.main.async` closure makes this
    /// equivalent to `.receive(on: DispatchQueue.main).sink { ... }`. Tests can
    /// pass `{ $0() }` to deliver values synchronously, which lets coordinator
    /// tests assert on side effects without pumping the runloop.
    ///
    /// (Previously this used `Container.shared.mainScheduler()` to resolve a
    /// scheduler from the consumer's DI container. The closure form drops the
    /// dependency on Factory entirely so the package stays DI-agnostic.)
    ///
    /// `receiveValue` is `@MainActor` because the call sites (coordinator
    /// navigation handlers, populate bindings) all touch UIKit. The schedule
    /// closure runs first on whatever thread the upstream sinks on, then hops
    /// to main via `MainActor.assumeIsolated`.
    func sinkOnMain(
        schedule: @escaping @Sendable (@escaping @Sendable () -> Void)
            -> Void = { DispatchQueue.main.async(execute: $0) },
        _ receiveValue: @escaping @Sendable @MainActor (Output) -> Void
    ) -> AnyCancellable where Output: Sendable {
        sink { value in
            schedule {
                MainActor.assumeIsolated { receiveValue(value) }
            }
        }
    }
}

// MARK: - --> binding operator

infix operator -->

// Each `-->` overload accepts `some Publisher<…, Never>` rather than the
// concrete `AnyPublisher<…, Never>` so call sites can drop a chained
// expression (`.map`, `.combineLatest`, `.removeDuplicates`, …) straight
// into the binder without an explicit `.eraseToAnyPublisher()`.
//
// All overloads are `@MainActor` because the right-hand side is always a
// `Binder` (`@MainActor`) or a UIKit object (`@MainActor` in the iOS 26 SDK).
// `populate(with:)` — the canonical call site — is `@MainActor` already, so
// this isolation matches reality.

/// Binds a `Never`-failing publisher to a `Binder` — the write-only,
/// main-thread sink primitive used throughout `populate(with:)` implementations.
///
/// ## Example
///
/// ```swift
/// // Pre-erased publisher.
/// output.isEnabled --> button.isEnabledBinder
///
/// // Inline chain — no .eraseToAnyPublisher() needed.
/// output.isLoading.map { !$0 } --> formStack.isVisibleBinder
/// ```
@MainActor
@discardableResult
public func --> <T: Sendable>(publisher: some Publisher<T, Never>, binder: Binder<T>) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { value in
        MainActor.assumeIsolated { binder.on(value) }
    }
}

/// `-->` overload: binds a non-optional publisher into a `Binder` that accepts
/// an optional. Implicitly lifts the value to `.some(...)`.
@MainActor
@discardableResult
public func --> <T: Sendable>(publisher: some Publisher<T, Never>, binder: Binder<T?>) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { value in
        MainActor.assumeIsolated { binder.on(value) }
    }
}

/// `-->` overload: binds an optional publisher into a `Binder` of the same
/// optional type.
@MainActor
@discardableResult
public func --> <T: Sendable>(publisher: some Publisher<T?, Never>, binder: Binder<T?>) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { value in
        MainActor.assumeIsolated { binder.on(value) }
    }
}

/// `-->` overload: binds a string publisher directly into a `UILabel`'s `text`.
@MainActor
@discardableResult
public func --> (publisher: some Publisher<String, Never>, label: UILabel) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { [weak label] value in
        MainActor.assumeIsolated { label?.text = value }
    }
}

/// `-->` overload: same as the `String` variant but for optional strings.
@MainActor
@discardableResult
public func --> (publisher: some Publisher<String?, Never>, label: UILabel) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { [weak label] value in
        MainActor.assumeIsolated { label?.text = value }
    }
}

/// `-->` overload: binds a string publisher directly into a `UITextView`'s `text`.
@MainActor
@discardableResult
public func --> (publisher: some Publisher<String, Never>, textView: UITextView) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { [weak textView] value in
        MainActor.assumeIsolated { textView?.text = value }
    }
}

/// `-->` overload: same as the `String` variant but for optional strings.
@MainActor
@discardableResult
public func --> (publisher: some Publisher<String?, Never>, textView: UITextView) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { [weak textView] value in
        MainActor.assumeIsolated { textView?.text = value }
    }
}
