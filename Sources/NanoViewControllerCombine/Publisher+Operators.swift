// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import UIKit

// MARK: - sinkOnMain

public extension Publisher where Failure == Never {
    /// Subscribes and dispatches each value to a `@MainActor` closure.
    ///
    /// In production the default `DispatchQueue.main.async` schedule makes
    /// this equivalent to `.receive(on: DispatchQueue.main).sink { … }`.
    /// Tests can pass `{ $0() }` to deliver values synchronously, which lets
    /// coordinator tests assert on side effects without pumping the runloop.
    ///
    /// > Important: The `schedule` closure **must** invoke its inner block on
    /// > the main thread. The default does, via `DispatchQueue.main.async`. A
    /// > test fake that wants synchronous delivery (`schedule: { $0() }`)
    /// > must therefore be called from a `@MainActor` test method. If the
    /// > inner block runs off-main, the
    /// > `MainActor.assumeIsolated`-bound call to `receiveValue` will trap.
    /// > In practice this is exactly the contract callers want — they're
    /// > driving UIKit-bound `@MainActor` handlers — but the precondition is
    /// > worth stating explicitly.
    ///
    /// ## Example
    ///
    /// ```swift
    /// viewModel.navigator.navigation
    ///     .sinkOnMain { [weak self] step in self?.handle(step) }
    ///     .store(in: &cancellables)
    /// ```
    ///
    /// - Parameters:
    ///   - schedule: Closure that decides how to dispatch the receive callback.
    ///     Must invoke its inner block on the main thread. Defaults to
    ///     `DispatchQueue.main.async`.
    ///   - receiveValue: The handler invoked for each received value, on the
    ///     main actor.
    /// - Returns: The cancellable subscription.
    func sinkOnMain(
        schedule: @escaping @Sendable (@escaping @Sendable () -> Void)
            -> Void = { DispatchQueue.main.async(execute: $0) },
        _ receiveValue: @escaping @MainActor (Output) -> Void
    ) -> AnyCancellable where Output: Sendable {
        sink { value in
            schedule {
                MainActor.assumeIsolated { receiveValue(value) }
            }
        }
    }
}

// MARK: - --> binding operator

/// Binding operator. Reads as "the publisher on the left flows into the
/// binder on the right".
///
/// All overloads accept `some Publisher<…, Never>` (rather than the concrete
/// `AnyPublisher`), so chained expressions like `.map`/`.combineLatest`/
/// `.removeDuplicates` drop straight in without an explicit
/// `.eraseToAnyPublisher()`.
///
/// All overloads are `@MainActor` because `Binder` is `@MainActor` and the
/// UIKit targets (UILabel, UITextView) are `@MainActor` in iOS 26. The
/// canonical call site is `populate(with:)`, which is itself `@MainActor`.
infix operator -->

/// Binds a `Never`-failing publisher to a ``Binder``.
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
