// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// Write-only wrapper that always applies values on the main thread.
///
/// A `Binder<Value>` wraps a writing closure that targets some UI object with a
/// weak reference so it can't extend the object's lifetime. The `-->` operator
/// (`Publisher+Operators.swift`) drives values into a binder; UIKit extensions
/// expose binders as properties (e.g. `UIControl.isEnabledBinder`,
/// `UIView.isVisibleBinder`).
///
/// `@MainActor` because every binding writes to a UIKit object — `@MainActor`
/// in the iOS 26 SDK. The `-->` operator hops to `RunLoop.main` first and then
/// uses `MainActor.assumeIsolated` to call ``on(_:)``, so backing off to a
/// `Thread.isMainThread`-style runtime check is no longer needed.
@MainActor
public struct Binder<Value> {
    /// Closure that applies a value to the wrapped (weakly-held) object.
    /// Assigned once in `init` and never mutated.
    private let _binding: (Value) -> Void

    /// Creates a binder that writes `Value`s into `object` via `binding`.
    ///
    /// `object` is captured weakly. If the underlying object has been deallocated
    /// by the time a value arrives, the write is silently dropped.
    public init<Object: AnyObject>(
        _ object: Object,
        binding: @escaping (Object, Value) -> Void
    ) {
        _binding = { [weak object] value in
            guard let object else { return }
            binding(object, value)
        }
    }

    /// Writes `value` through the wrapped binding on the main thread.
    public func on(_ value: Value) {
        _binding(value)
    }
}
