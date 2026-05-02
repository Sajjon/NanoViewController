// MIT License — Copyright (c) 2018-2026 Open Zesame

import UIKit

/// Abstracts over `UINotificationFeedbackGenerator`.
///
/// Tests register a mock implementation so unit tests never trigger a real
/// device vibration. On-device haptics can leak across concurrent test runs
/// (the haptic engine is a single shared resource) and interfere with UI
/// tests that observe device state.
///
/// ## Example — light haptic on copy
///
/// ```swift
/// import NanoViewControllerDIPrimitives
///
/// final class ReceiveAddressViewModel {
///     private let pasteboard: any Pasteboard
///     private let haptics:    any HapticFeedback
///
///     init(pasteboard: any Pasteboard, haptics: any HapticFeedback) {
///         self.pasteboard = pasteboard
///         self.haptics    = haptics
///     }
///
///     func copyAddress(_ address: String) {
///         pasteboard.copy(address)
///         haptics.notify(.success)        // <- the user feels the copy
///     }
/// }
///
/// // Test:
/// final class RecordingHaptics: HapticFeedback {
///     private(set) var calls: [UINotificationFeedbackGenerator.FeedbackType] = []
///     func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
///         calls.append(type)
///     }
/// }
///
/// let haptics = RecordingHaptics()
/// let vm = ReceiveAddressViewModel(pasteboard: MockPasteboard(),
///                                  haptics:    haptics)
/// vm.copyAddress("0xabc…")
/// XCTAssertEqual(haptics.calls, [.success])
/// ```
public protocol HapticFeedback: AnyObject {
    /// Fires a system haptic pulse of the requested `type`.
    ///
    /// - Parameter type: The notification flavour — `.success`, `.warning`, `.error`.
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType)
}

/// Production ``HapticFeedback`` backed by `UINotificationFeedbackGenerator`.
public final class DefaultHapticFeedback: HapticFeedback {
    private let generator = UINotificationFeedbackGenerator()

    /// Trivial init — no dependencies.
    public init() {}

    /// Forwards to `UINotificationFeedbackGenerator.notificationOccurred(_:)`.
    public func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        generator.notificationOccurred(type)
    }
}
