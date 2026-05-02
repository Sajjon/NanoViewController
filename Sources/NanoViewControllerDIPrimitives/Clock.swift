// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// Abstracts over delayed dispatch so callers can be tested without real-time
/// waits.
///
/// Production code uses ``MainQueueClock``, which schedules work with a real
/// `DispatchQueue.main.asyncAfter` delay. Tests register an immediate-clock
/// double that ignores the delay and fires on the next main-queue cycle —
/// making timer-dependent tests run in milliseconds instead of seconds.
///
/// `Clock` is the *delayed* sibling of ``MainScheduler``: `MainScheduler`
/// controls immediate hops to the main thread, `Clock` controls delayed
/// dispatch. Together they cover every place where the package would
/// otherwise need to call `DispatchQueue.main.async` or `.asyncAfter`
/// directly.
///
/// The package itself uses `Clock` only inside ``Toast/present(using:clock:dismissedCompletion:)``,
/// where the auto-dismiss path delays the dismissal by `duration` seconds.
/// Consumers can use it for any delayed work that needs to be testable.
///
/// ## Example — testable timed banner
///
/// ```swift
/// import NanoViewControllerDIPrimitives
///
/// final class TimedBannerViewModel {
///     private let clock: any Clock
///     private var work: DispatchWorkItem?
///
///     init(clock: any Clock) { self.clock = clock }
///
///     /// Show the banner; auto-hide after `duration` seconds.
///     func show(message: String, duration: TimeInterval) {
///         display(message)
///         work?.cancel()
///         work = clock.schedule(after: duration) { [weak self] in self?.hide() }
///     }
///
///     /// Cancel the auto-hide if the user dismisses early.
///     func dismissNow() {
///         work?.cancel()
///         work = nil
///         hide()
///     }
///
///     private func display(_ message: String) { /* … */ }
///     private func hide() { /* … */ }
/// }
///
/// // Test:
/// final class ImmediateClock: Clock {
///     @discardableResult
///     func schedule(after _: TimeInterval, execute block: @escaping () -> Void) -> DispatchWorkItem {
///         let item = DispatchWorkItem(block: block)
///         block()                  // fire synchronously
///         return item
///     }
/// }
///
/// let vm = TimedBannerViewModel(clock: ImmediateClock())
/// vm.show(message: "saved", duration: 5.0)
/// // The hide() body has already run by this point — no XCTestExpectation,
/// // no runloop pumping needed.
/// ```
public protocol Clock: AnyObject {
    /// Schedules `block` to run on the main thread after `delay` seconds.
    ///
    /// - Parameters:
    ///   - delay: Time interval, in seconds, to wait before firing.
    ///   - block: The work to perform on the main thread when the delay elapses.
    /// - Returns: A `DispatchWorkItem` that can be cancelled before it fires.
    @discardableResult
    func schedule(
        after delay: TimeInterval,
        execute block: @escaping () -> Void
    ) -> DispatchWorkItem
}

/// Production ``Clock`` implementation backed by `DispatchQueue.main.asyncAfter`.
///
/// ## Example
///
/// ```swift
/// let clock: any Clock = MainQueueClock()
/// clock.schedule(after: 0.6) { print("fired after 600ms") }
/// ```
public final class MainQueueClock: Clock {
    /// Trivial init — no dependencies.
    public init() {}

    /// Schedules `block` on `DispatchQueue.main` after `delay` seconds.
    ///
    /// Wraps the block in a `DispatchWorkItem` so the caller can cancel the
    /// pending work — useful when the delay is interrupted by user action
    /// (e.g. early manual dismiss of a toast).
    ///
    /// - Parameters:
    ///   - delay: Seconds to wait before firing.
    ///   - block: The work to perform on the main thread.
    /// - Returns: The cancellable `DispatchWorkItem` that wraps `block`.
    @discardableResult
    public func schedule(
        after delay: TimeInterval,
        execute block: @escaping () -> Void
    ) -> DispatchWorkItem {
        let item = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return item
    }
}
