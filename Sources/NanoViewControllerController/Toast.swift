// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerDIPrimitives
import NanoViewControllerNavigation
import UIKit

/// A lightweight text message the UI surfaces as an auto-dismissing alert,
/// named after the Android equivalent.
///
/// ViewModels `send(Toast(...))` into `InputFromController.toastSubject` to
/// request a display; the `SceneController` presents it on the active view
/// controller.
///
/// `@unchecked Sendable` because of the optional `Completion` closure — the
/// type system can't prove the closure is `@Sendable`, but in practice the
/// callback fires on the main thread inside `present(using:clock:...)`.
public struct Toast: @unchecked Sendable {
    /// Describes how the toast should disappear after presentation.
    public enum Dismissing {
        /// Dismiss automatically after `duration` seconds.
        case after(duration: TimeInterval)

        /// Wait for the user to tap the dismiss button with the given title.
        case manual(dismissButtonTitle: String)
    }

    /// The body text shown inside the toast.
    private let message: String

    /// How the toast is torn down once presented.
    private let dismissing: Dismissing

    /// Optional callback invoked when the toast is dismissed.
    private let completion: Completion?

    /// Creates a toast. Default `dismissing` is "auto-dismiss after 0.6 s".
    public init(_ message: String, dismissing: Dismissing = .after(duration: 0.6), completion: Completion? = nil) {
        self.message = message
        self.dismissing = dismissing
        self.completion = completion
    }
}

// MARK: ExpressibleByStringLiteral

extension Toast: ExpressibleByStringLiteral {
    public init(stringLiteral message: String) {
        self.init(message)
    }
}

// MARK: - Toast + Presentation

public extension Toast {
    /// Presents the toast on `navigationController`. The auto-dismiss path
    /// schedules the dismiss via `clock.schedule(after:)` — pass an immediate
    /// clock in tests, the production `MainQueueClock` in production. The
    /// package itself does not own a DI container, so the `clock` parameter
    /// is the only acceptable way to inject delayed dispatch here.
    ///
    /// `@MainActor` because every UIKit construction (`UIAlertController`,
    /// `UIAlertAction`, `present(_:animated:completion:)`) is main-thread-bound
    /// in the iOS 26 SDK.
    @MainActor
    func present(
        using navigationController: UIViewController,
        clock: any Clock,
        dismissedCompletion: Completion? = nil
    ) {
        let dismissedCompletion = dismissedCompletion ?? completion
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        switch dismissing {
        case let .manual(dismissTitle):
            let dismissAction = UIAlertAction(title: dismissTitle, style: .default) { _ in
                dismissedCompletion?()
            }
            alert.addAction(dismissAction)
        case let .after(duration):
            // The clock callback may fire on any thread; hop back to main
            // before touching UIKit. `assumeIsolated` is safe here because the
            // production `MainQueueClock` schedules on `DispatchQueue.main`.
            //
            // The completion is passed through an `@unchecked Sendable` box
            // so the `@Sendable` clock closure can capture it. Safe in practice
            // because the wrapped closure only ever fires on the main thread.
            let box = UncheckedSendableBox(dismissedCompletion)
            clock.schedule(after: duration) {
                MainActor.assumeIsolated {
                    alert.dismiss(animated: true, completion: box.value)
                }
            }
        }

        navigationController.present(alert, animated: true, completion: nil)
    }
}
