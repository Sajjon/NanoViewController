// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Foundation

/// Abstracts over delayed dispatch on the main actor so callers can be tested
/// without real-time waits.
///
/// Production code uses ``MainQueueClock``, which schedules work via
/// `Task { @MainActor in try? await Task.sleep(...); block() }`. Tests register
/// an immediate-clock double that ignores the delay and fires synchronously,
/// making timer-dependent tests run in milliseconds.
///
/// `Clock` is the *delayed* sibling of ``MainScheduler``: `MainScheduler`
/// controls immediate hops to the main actor, `Clock` controls delayed
/// dispatch. Together they cover every place where the package would
/// otherwise need to call `DispatchQueue.main.async` or `.asyncAfter`
/// directly.
///
/// The package itself uses `Clock` only inside ``Toast/present(using:clock:dismissedCompletion:)``,
/// where the auto-dismiss path delays the dismissal by `duration` seconds.
/// Consumers can use it for any main-actor work that needs to be testable.
///
/// `@MainActor` because the protocol's `block` parameter is implicitly
/// `@MainActor`, which matches every observed use-site (UI dismissals,
/// label updates, etc.). No `@Sendable` ceremony is needed because the
/// closure never crosses an actor boundary.
///
/// ## Example — testable timed banner
///
/// ```swift
/// import NanoViewControllerDIPrimitives
///
/// @MainActor
/// final class TimedBannerViewModel {
///     private let clock: any Clock
///     private var pending: Task<Void, Never>?
///
///     init(clock: any Clock) { self.clock = clock }
///
///     /// Show the banner; auto-hide after `duration` seconds.
///     func show(message: String, duration: TimeInterval) {
///         display(message)
///         pending?.cancel()
///         pending = clock.schedule(after: duration) { [weak self] in self?.hide() }
///     }
///
///     /// Cancel the auto-hide if the user dismisses early.
///     func dismissNow() {
///         pending?.cancel()
///         pending = nil
///         hide()
///     }
///
///     private func display(_ message: String) { /* … */ }
///     private func hide() { /* … */ }
/// }
///
/// // Test:
/// @MainActor
/// final class ImmediateClock: Clock {
///     @discardableResult
///     func schedule(after _: TimeInterval, execute block: @escaping () -> Void) -> Task<Void, Never> {
///         block()                                    // fire synchronously
///         return Task { /* no-op, already fired */ }
///     }
/// }
///
/// let vm = TimedBannerViewModel(clock: ImmediateClock())
/// vm.show(message: "saved", duration: 5.0)
/// // hide() has already run by this point — no XCTestExpectation needed.
/// ```
@MainActor
public protocol Clock: AnyObject {
    /// Schedules `block` to run on the main actor after `delay` seconds.
    ///
    /// - Parameters:
    ///   - delay: Time interval, in seconds, to wait before firing.
    ///   - block: The work to perform when the delay elapses.
    /// - Returns: A `Task` that can be cancelled before it fires.
    @discardableResult
    func schedule(
        after delay: TimeInterval,
        execute block: @escaping () -> Void
    ) -> Task<Void, Never>
}

/// Production ``Clock`` implementation backed by `Task` + `Task.sleep`.
///
/// ## Example
///
/// ```swift
/// let clock: any Clock = MainQueueClock()
/// clock.schedule(after: 0.6) { print("fired after 600ms") }
/// ```
@MainActor
public final class MainQueueClock: Clock {
    /// Trivial init — no dependencies.
    public init() {}

    /// Schedules `block` to run on the main actor after `delay` seconds.
    ///
    /// Implemented via Swift Concurrency: a `@MainActor` `Task` sleeps for
    /// `delay`, then fires `block` if it wasn't cancelled. Callers cancel by
    /// calling `.cancel()` on the returned `Task`.
    ///
    /// - Parameters:
    ///   - delay: Seconds to wait before firing.
    ///   - block: The work to perform on the main actor.
    /// - Returns: The cancellable `Task` that wraps the delay + `block`.
    @discardableResult
    public func schedule(
        after delay: TimeInterval,
        execute block: @escaping () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            block()
        }
    }
}
