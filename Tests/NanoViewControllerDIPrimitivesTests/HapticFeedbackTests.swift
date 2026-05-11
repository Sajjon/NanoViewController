// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

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
        let haptics = DefaultHapticFeedback()
        haptics.notify(.success)
    }

    func test_notify_warning_doesNotCrash() {
        let haptics = DefaultHapticFeedback()
        haptics.notify(.warning)
    }

    func test_notify_error_doesNotCrash() {
        let haptics = DefaultHapticFeedback()
        haptics.notify(.error)
    }
}
