// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Foundation

/// Write-only wrapper that always applies values on the main thread.
///
/// A `Binder<Value>` wraps a writing closure that targets some UI object with
/// a *weak* reference, so it can't extend the object's lifetime. The
/// ``-->(_:_:)-...`` operator (defined in `Publisher+Operators.swift`) drives
/// values into a binder; UIKit extensions in this module expose binders as
/// properties (e.g. ``UIControl/isEnabledBinder``,
/// ``UIView/isVisibleBinder``).
///
/// The binder is the project's answer to the "main-thread, weak-target,
/// receive-only sink" pattern that you write by hand at every UIKit binding
/// site. Centralising it means every binding gets the same guarantees:
///
///   * The wrapped object is captured weakly — no retain cycles, ever.
///   * Writes happen on the main actor (the binder is `@MainActor`); the
///     `-->` operator hops to `RunLoop.main` first, so callers don't have
///     to think about thread affinity at the binding site.
///   * Writes after the wrapped object is deallocated are silently dropped.
///
/// ## Example — wiring up a custom binder
///
/// ```swift
/// import Combine
/// import NanoViewControllerCombine
/// import UIKit
///
/// extension MyCustomCardView {
///     /// Binder that drives the card's elevation level.
///     var elevationBinder: Binder<Int> {
///         Binder(self) { card, level in
///             card.layer.shadowOpacity = Float(level) / 10
///             card.layer.shadowRadius  = CGFloat(level)
///         }
///     }
/// }
///
/// // Usage in a populate(with:) implementation:
/// func populate(with publishers: ViewModel.Publishers) -> [AnyCancellable] {
///     publishers.elevation --> card.elevationBinder
///     publishers.title     --> titleLabel                     // -- string overload
///     publishers.isEnabled --> primaryButton.isEnabledBinder  // -- bool binder
/// }
/// ```
///
/// ## Example — using the `-->` operator
///
/// The companion operator does `receive(on: RunLoop.main).sink { binder.on($0) }`
/// for you, returning an `AnyCancellable` you can collect:
///
/// ```swift
/// // viewModelOutput.title is `AnyPublisher<String, Never>`
/// let cancellable = viewModelOutput.title --> titleLabel
/// // store it: cancellable.store(in: &cancellables)
/// ```
///
/// `@MainActor` because every binding writes to a UIKit object — `@MainActor`
/// in the iOS 26 SDK. The `-->` operator hops to `RunLoop.main` first, so by
/// the time `on(_:)` runs the caller is already on the main actor.
@MainActor
public struct Binder<Value> {
    /// Closure that applies a value to the wrapped (weakly-held) object.
    /// Assigned once in ``init(_:binding:)`` and never mutated afterwards.
    private let _binding: (Value) -> Void

    /// Creates a binder that writes `Value`s into `object` via `binding`.
    ///
    /// `object` is captured **weakly**. If the underlying object has been
    /// deallocated by the time a value arrives, the write is silently
    /// dropped — common when a long-lived ViewModel keeps emitting after
    /// the view has been torn down.
    ///
    /// - Parameters:
    ///   - object: The UI object to write into. Captured weakly.
    ///   - binding: Closure invoked on the main actor with the most recent
    ///     value and a strong reference to `object`.
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
    ///
    /// Called by the ``-->(_:_:)-...`` operator on each emission. Callers
    /// rarely invoke this directly — the operator is the standard way.
    ///
    /// - Parameter value: The value to apply to the wrapped object.
    public func on(_ value: Value) {
        _binding(value)
    }
}
