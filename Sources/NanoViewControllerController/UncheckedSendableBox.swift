// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// Pass-through box for ferrying a non-`Sendable` value through a `@Sendable`
/// closure capture site.
///
/// The compiler can't prove the wrapped value is safe to send across an actor
/// boundary, so we attest with `@unchecked Sendable`. Use sparingly and only
/// when you can manually verify the value never *actually* races (e.g. a
/// callback that always fires on the main thread, even though its type
/// signature doesn't say so).
///
/// ## Example — bridging a non-`Sendable` callback into `@Sendable` clock work
///
/// ```swift
/// let box = UncheckedSendableBox(userSuppliedCallback)
/// clock.schedule(after: 0.5) {
///     MainActor.assumeIsolated { box.value?() }
/// }
/// ```
public struct UncheckedSendableBox<Value>: @unchecked Sendable {
    /// The wrapped value. Read-only — the box is constructed once and consumed.
    public let value: Value

    /// Wraps `value`.
    public init(_ value: Value) {
        self.value = value
    }
}
