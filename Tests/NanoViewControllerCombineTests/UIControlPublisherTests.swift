// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCombine
import UIKit
import XCTest

/// Tests for `UIControlPublisher` and its private `UIControlSubscription`,
/// focusing on the concurrency-sensitive paths:
///
///   * subscribe + cancel on main, repeatedly, doesn't trap;
///   * `cancel()` invoked from a *non-main* context (the `AnyCancellable`-
///     deinit-runs-off-main path) doesn't trap. The previous revision's
///     `MainActor.assumeIsolated` would have. The current `runOnMain`
///     helper hops via `DispatchQueue.main.async` instead, and writes
///     `subscriber = nil` from inside the same main-thread block as the
///     `removeTarget` call so there's no read/write race.
///
/// `UIControl.sendActions(for:)` does not fire registered targets in the iOS
/// 26 simulator without actual touch tracking, so the value-delivery test
/// invokes the registered target/action directly.
@MainActor
final class UIControlPublisherTests: XCTestCase {
    private func makeButton() -> UIButton {
        UIButton(type: .system)
    }

    // MARK: - On-main subscribe + cancel (smoke)

    func test_subscribeAndCancelOnMain_doesNotTrap() {
        // ARRANGE
        let button = makeButton()
        let cancellable = button.publisher(for: .touchUpInside).sink { _ in }

        // ACT
        cancellable.cancel()

        // ASSERT
        // Reaching this line means no `MainActor.assumeIsolated` trap fired.
        XCTAssertTrue(true)
    }

    func test_repeatedSubscribeCancelCycles_doNotLeak() {
        // ARRANGE
        let button = makeButton()

        // ACT
        for _ in 0 ..< 50 {
            let cancellable = button.publisher(for: .touchUpInside).sink { _ in }
            cancellable.cancel()
        }

        // ASSERT
        // Cycles complete without trap; UIKit's target/action map is left
        // empty (`removeTarget` ran on each cancel).
        XCTAssertEqual(button.allTargets.count, 0)
    }

    func test_tapPublisherForwardsRegisteredTargetAction() throws {
        // ARRANGE
        let button = makeButton()
        var tapCount = 0
        let cancellable = button.tapPublisher.sink { tapCount += 1 }

        let target = try XCTUnwrap(button.allTargets.first as? NSObject)
        let actions = try XCTUnwrap(button.actions(forTarget: target, forControlEvent: .touchUpInside))

        // ACT
        target.perform(NSSelectorFromString(actions[0]))

        // ASSERT
        XCTAssertEqual(actions, ["fire"])
        XCTAssertEqual(tapCount, 1)
        cancellable.cancel()
    }

    // MARK: - Off-main cancel (the AnyCancellable.deinit path)

    func test_cancelOffMain_doesNotTrap() async {
        // ARRANGE
        let button = await MainActor.run { makeButton() }
        // Build the subscription on main. Wrap the resulting cancellable in
        // an `@unchecked Sendable` box so we can hand it to `Task.detached`
        // without `AnyCancellable` itself needing to be `Sendable`.
        let box = await MainActor.run {
            UncheckedSendableBox(
                button.publisher(for: .touchUpInside).sink { _ in }
            )
        }

        // ACT
        // Cancel from a *non-main* context. The previous revision would
        // trap here inside `MainActor.assumeIsolated`. The `runOnMain`
        // helper now hops via `DispatchQueue.main.async`.
        let detached = Task.detached {
            box.value.cancel()
        }
        await detached.value
        // Yield long enough for the async `removeTarget` + `subscriber = nil`
        // to land on main.
        try? await Task.sleep(for: .milliseconds(50))

        // ASSERT
        // Reaching this point means the off-main cancel completed without
        // trapping AND without crashing on a stale target/action pointer.
        let remainingTargets = await MainActor.run { button.allTargets.count }
        XCTAssertEqual(remainingTargets, 0)
    }

    // MARK: - Weak control reference

    func test_publisherDoesNotRetain_control() {
        // ARRANGE
        weak var weakButton: UIButton?

        // ACT
        autoreleasepool {
            let button = makeButton()
            weakButton = button
            // Subscribe and immediately cancel. After the autoreleasepool
            // drains, the publisher should not be the last strong reference.
            let cancellable = button.publisher(for: .touchUpInside).sink { _ in }
            cancellable.cancel()
        }

        // ASSERT
        XCTAssertNil(weakButton, "Publisher must not retain its control")
    }

    // MARK: - Helpers

    /// Pass-through box for ferrying a non-`Sendable` value through a
    /// `Task.detached` boundary in tests. Safe because `AnyCancellable.cancel()`
    /// is documented thread-safe by Combine, and we only invoke `.cancel()`
    /// on the captured value.
    private struct UncheckedSendableBox<Value>: @unchecked Sendable {
        let value: Value
        init(_ value: Value) {
            self.value = value
        }
    }
}
