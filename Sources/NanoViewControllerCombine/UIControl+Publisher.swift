// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import UIKit

// MARK: - UIControl event publisher

/// Tiny weak holder used to avoid the `UIControl` retaining the publisher
/// (or vice versa) through closure capture.
private final class WeakBox<Object: AnyObject> {
    weak var value: Object?
    init(_ value: Object) {
        self.value = value
    }
}

/// Publisher that emits a `Void` event each time its underlying `Control`
/// fires the bitmask of `UIControl.Event`s it was created with.
///
/// Callers don't usually instantiate this directly — use the
/// `UIControl.publisher(for:)` helper (defined below) or one of the
/// pre-built publishers in `UIControl+Publishers.swift`.
///
/// ## Example
///
/// ```swift
/// import Combine
/// import NanoViewControllerCombine
/// import UIKit
///
/// let valueChanged = slider.publisher(for: .valueChanged)
/// // .valueChanged is a UIControlPublisher<UIControl> emitting Void on each move.
///
/// valueChanged
///     .compactMap { [weak slider] _ in slider?.value }
///     .sink { value in print("slider:", value) }
///     .store(in: &cancellables)
/// ```
public struct UIControlPublisher<Control: UIControl>: Publisher {
    public typealias Output = Void
    public typealias Failure = Never

    private let control: WeakBox<Control>
    let events: UIControl.Event

    init(control: Control, events: UIControl.Event) {
        self.control = WeakBox(control)
        self.events = events
    }

    public func receive<S: Subscriber>(subscriber: S)
        where S.Input == Void, S.Failure == Never
    {
        guard let control = control.value else {
            // Control already dead — finish immediately so downstream sinks
            // tear down cleanly instead of waiting on a dangling source.
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: .finished)
            return
        }
        let subscription = UIControlSubscription(
            subscriber: subscriber,
            control: control,
            events: events
        )
        subscriber.receive(subscription: subscription)
    }
}

/// Per-subscription `Subscription` object backing ``UIControlPublisher``.
///
/// Holds the `Control` weakly and registers itself as the `target` for the
/// requested event mask. On `cancel()` it removes itself as the target so the
/// `UIControl` no longer retains a reference to the subscription.
final class UIControlSubscription<S: Subscriber, Control: UIControl>: Subscription
    where S.Input == Void, S.Failure == Never
{
    private var subscriber: S?
    private weak var control: Control?
    private let events: UIControl.Event

    init(subscriber: S, control: Control, events: UIControl.Event) {
        self.subscriber = subscriber
        self.control = control
        self.events = events
        control.addTarget(self, action: #selector(handleEvent), for: events)
    }

    /// We're an unbounded source — UIKit events arrive whenever they arrive
    /// and we deliver them all. No demand-tracking needed.
    func request(_: Subscribers.Demand) {}

    /// Drops the target/action registration and forgets the subscriber so
    /// future events become no-ops.
    func cancel() {
        control?.removeTarget(self, action: #selector(handleEvent), for: events)
        subscriber = nil
    }

    @objc private func handleEvent() {
        _ = subscriber?.receive(())
    }
}

// MARK: - UIControl extension

public extension UIControl {
    /// Returns a `Publisher` that fires each time this control emits any of the
    /// supplied `events`.
    ///
    /// The publisher holds the control weakly; once the control is released,
    /// the publisher completes.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // A Combine wrapper for editing-changed:
    /// let typing = textField.publisher(for: .editingChanged)
    ///     .compactMap { [weak textField] _ in textField?.text }
    /// ```
    ///
    /// - Parameter events: Bitmask of UIKit control events to observe.
    /// - Returns: A `UIControlPublisher` emitting `Void` on each matched event.
    func publisher(for events: UIControl.Event) -> UIControlPublisher<UIControl> {
        UIControlPublisher(control: self, events: events)
    }
}
