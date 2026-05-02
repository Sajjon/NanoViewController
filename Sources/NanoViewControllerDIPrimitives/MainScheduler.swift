// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// Abstracts main-thread scheduling so navigation/UI hops can be swapped for
/// synchronous delivery in tests.
///
/// Sibling concept to ``Clock``:
///
///   * ``Clock`` controls *delayed* dispatch (`asyncAfter`).
///   * ``MainScheduler`` controls *immediate* dispatch (`async` / Combine's
///     `.receive(on: DispatchQueue.main)`).
///
/// Production registers ``DispatchMainScheduler``, which hops via
/// `DispatchQueue.main.async`. Tests register ``ImmediateMainScheduler``,
/// which invokes work synchronously on the calling thread. With the immediate
/// scheduler in place, coordinator/navigation tests can assert on side
/// effects without pumping the runloop.
///
/// ## Example — DI-friendly main-thread hop
///
/// ```swift
/// import NanoViewControllerDIPrimitives
///
/// final class CartViewModel {
///     private let scheduler: any MainScheduler
///
///     init(scheduler: any MainScheduler) { self.scheduler = scheduler }
///
///     func addToCart(_ item: Item, completion: @escaping () -> Void) {
///         api.add(item) { [scheduler] in
///             scheduler.schedule(completion)         // hop to main once
///         }
///     }
/// }
///
/// // Production:
/// let vm = CartViewModel(scheduler: DispatchMainScheduler())
///
/// // Test:
/// var done = false
/// let vm   = CartViewModel(scheduler: ImmediateMainScheduler())
/// vm.addToCart(item) { done = true }
/// XCTAssertTrue(done)        // ImmediateMainScheduler ran synchronously.
/// ```
public protocol MainScheduler: AnyObject {
    /// Schedules `work` to run on the main thread.
    ///
    /// Implementations may run synchronously (test fakes) or asynchronously
    /// (production), so callers must not assume `work` has finished by the
    /// time `schedule` returns.
    ///
    /// - Parameter work: Block to execute on the main thread.
    func schedule(_ work: @escaping () -> Void)
}

/// Production ``MainScheduler`` backed by `DispatchQueue.main.async`.
public final class DispatchMainScheduler: MainScheduler {
    /// Trivial init — no dependencies.
    public init() {}

    /// Hops `work` to the main queue via `async`.
    public func schedule(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }
}

/// Test ``MainScheduler`` that invokes work synchronously on the calling
/// thread.
///
/// Lets navigation hops resolve before the test's next assertion. **Do not**
/// use in production — synchronous delivery on a non-main thread will violate
/// UIKit's main-thread requirement.
///
/// ## Example
///
/// ```swift
/// var calls = 0
/// let scheduler = ImmediateMainScheduler()
/// scheduler.schedule { calls += 1 }
/// XCTAssertEqual(calls, 1)        // already incremented; no runloop pump needed
/// ```
public final class ImmediateMainScheduler: MainScheduler {
    /// Trivial init — no dependencies.
    public init() {}

    /// Invokes `work()` directly. No queue hop, no async behaviour.
    public func schedule(_ work: @escaping () -> Void) {
        work()
    }
}
