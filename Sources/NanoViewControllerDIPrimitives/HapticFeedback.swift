// MIT License — Copyright (c) 2018-2026 Open Zesame

import UIKit

/// Abstracts over `UINotificationFeedbackGenerator`. Tests register a mock so
/// unit tests never trigger a real device vibration (on-device haptics can
/// leak across concurrent test runs and interfere with UI tests).
///
/// `@MainActor` because `UIFeedbackGenerator` is main-thread-bound under the
/// iOS 26 SDK.
@MainActor
public protocol HapticFeedback: AnyObject {
    /// Fires a system haptic pulse of the requested `type`.
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType)
}

/// Production `HapticFeedback` backed by `UINotificationFeedbackGenerator`.
@MainActor
public final class DefaultHapticFeedback: HapticFeedback {
    private let generator = UINotificationFeedbackGenerator()

    public init() {}

    public func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        generator.notificationOccurred(type)
    }
}
