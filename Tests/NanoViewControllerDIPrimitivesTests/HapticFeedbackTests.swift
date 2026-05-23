// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

@testable import NanoViewControllerDIPrimitives
import UIKit
import XCTest

/// Tests for `DefaultHapticFeedback` — the production impl that forwards to
/// `UINotificationFeedbackGenerator.notificationOccurred(_:)`. The simulator
/// has no haptic hardware so the system call is a no-op; we exercise it for
/// each `FeedbackType` to ensure the production path does not trap and to
/// keep the line covered.
@MainActor
final class HapticFeedbackTests: XCTestCase {
    func test_notify_success_doesNotCrash() {
        // ARRANGE
        let haptics = DefaultHapticFeedback()

        // ACT
        haptics.notify(.success)

        // ASSERT
        // Reaching this line means the production call did not trap.
    }

    func test_notify_warning_doesNotCrash() {
        // ARRANGE
        let haptics = DefaultHapticFeedback()

        // ACT
        haptics.notify(.warning)

        // ASSERT
        // Reaching this line means the production call did not trap.
    }

    func test_notify_error_doesNotCrash() {
        // ARRANGE
        let haptics = DefaultHapticFeedback()

        // ACT
        haptics.notify(.error)

        // ASSERT
        // Reaching this line means the production call did not trap.
    }
}
