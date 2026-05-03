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
///
/// `@unchecked Sendable` because:
///
/// 1. Combine's `Subscription` is a *non-isolated* protocol, so this class
///    cannot be `@MainActor` (a `@MainActor` class can't satisfy
///    `nonisolated func request(_:)` / `cancel()` without `nonisolated` on
///    each method, which then can't touch the `@MainActor`-bound `control`).
/// 2. `addTarget` and `removeTarget` are `@MainActor`-only. They run inside
///    `MainActor.assumeIsolated`, which is sound because the publisher is
///    only ever subscribed-to from `populate(with:)` — itself `@MainActor`.
/// 3. The `@objc` selector `handleEvent` is dispatched by UIKit on the main
///    thread, so the `subscriber` reference is touched serially from a
///    single thread.
///
/// The `@unchecked` is therefore an *attestation* of these invariants, not
/// a hand-wave: every entry point either runs on `MainActor` or is dispatched
/// by UIKit on the main thread.
final class UIControlSubscription<S: Subscriber, Control: UIControl>: Subscription, @unchecked Sendable
    where S.Input == Void, S.Failure == Never
{
    private var subscriber: S?
    private weak var control: Control?
    private let events: UIControl.Event

    /// Non-generic `@objc` target. Generic classes can't reliably expose
    /// their `@objc` methods to the Obj-C runtime (the synthesised selector
    /// names get mangled with the generic specialisation), so the actual
    /// `target/action` registration goes through this dedicated, plain
    /// `NSObject` subclass. The action forwards to the subscription via a
    /// captured callback.
    private let target = ControlEventTarget()

    init(subscriber: S, control: Control, events: UIControl.Event) {
        self.subscriber = subscriber
        self.control = control
        self.events = events
        // `addTarget` is `@MainActor` in iOS 26. The publisher is only ever
        // subscribed-to from `populate(with:)` (already main-actor), so the
        // common path is `Thread.isMainThread == true`. Hop to main as a
        // safety net for any caller that subscribes off-main.
        //
        // Strong capture of `self` is intentional: the closure must run
        // before any event fires (otherwise the subscription is missing its
        // target/action registration). The capture extends `self`'s lifetime
        // only until the closure runs, after which the closure is released.
        Self.runOnMain { [self] in
            target.callback = { [weak self] in
                _ = self?.subscriber?.receive(())
            }
            control.addTarget(target, action: #selector(ControlEventTarget.fire), for: events)
        }
    }

    /// We're an unbounded source — UIKit events arrive whenever they arrive
    /// and we deliver them all. No demand-tracking needed.
    func request(_: Subscribers.Demand) {}

    /// Drops the target/action registration and forgets the subscriber so
    /// future events become no-ops.
    ///
    /// Combine may invoke `cancel()` from any thread (e.g. `AnyCancellable`
    /// `deinit` running off-main), so we hop to main rather than asserting
    /// isolation. Both the `removeTarget` call AND the `subscriber = nil`
    /// write happen inside the same main-thread block, so the action
    /// callback (which only fires on main) never observes a torn write.
    ///
    /// Strong capture of `self` extends the subscription's lifetime until
    /// the main hop completes. A `[weak self]` capture would race with
    /// `AnyCancellable.deinit` releasing its only strong reference: the hop
    /// could resolve `nil` before `removeTarget` ran, leaving a stale
    /// pointer in UIKit's target/action map.
    func cancel() {
        Self.runOnMain { [self] in
            control?.removeTarget(target, action: #selector(ControlEventTarget.fire), for: events)
            target.callback = nil
            subscriber = nil
        }
    }

    /// Runs a `@MainActor` block synchronously when already on main,
    /// otherwise hops via `DispatchQueue.main.async`. Avoids the
    /// `MainActor.assumeIsolated` trap for off-main `cancel()` calls.
    ///
    /// The block is statically `@MainActor` so the compiler enforces that
    /// call-site closures only touch main-actor-isolated state — the comment
    /// claim ("addTarget/removeTarget are main-actor-only") is now backed by
    /// the type system rather than a runtime precondition.
    private static func runOnMain(_ block: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { block() }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { block() }
            }
        }
    }
}

/// Non-generic `@objc` target that bridges UIKit's selector dispatch to a
/// Swift closure. Lives outside ``UIControlSubscription`` so its `@objc`
/// methods aren't subject to generic-specialisation name mangling.
private final class ControlEventTarget: NSObject {
    var callback: (() -> Void)?

    @objc func fire() {
        callback?()
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
