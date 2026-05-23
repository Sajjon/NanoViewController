// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import NanoViewControllerDIPrimitives
import NanoViewControllerNavigation
import UIKit

/// A lightweight text message the UI surfaces as an auto-dismissing alert,
/// named after the Android equivalent.
///
/// ViewModels `send(Toast(...))` into ``InputFromController/toastSubject`` to
/// request a display; the ``NanoViewController`` presents it on the active view
/// controller, using a ``Clock`` from ``NanoViewController/clock`` to schedule
/// the auto-dismiss.
///
/// ## Example — auto-dismissing toast on success
///
/// ```swift
/// // Inside a ViewModel transform(input:):
/// api.saveProfile(form)
///     .replaceError(with: ())
///     .map { _ in Toast("Profile saved") }            // String → Toast via ExpressibleByStringLiteral
///     .sink { input.fromController.toastSubject.send($0) }
///     .store(in: &cancellables)
/// ```
///
/// ## Example — manual-dismiss toast for an error
///
/// ```swift
/// errors.asPublisher()
///     .map { error -> Toast in
///         Toast(error.localizedDescription,
///               dismissing: .manual(dismissButtonTitle: "OK"))
///     }
///     .sink { input.fromController.toastSubject.send($0) }
///     .store(in: &cancellables)
/// ```
public struct Toast {
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

    /// Creates a toast.
    ///
    /// Default `dismissing` is "auto-dismiss after 0.6 s" — short enough that
    /// it doesn't block the user, long enough that they can read a
    /// confirmation string.
    ///
    /// - Parameters:
    ///   - message: Body text shown to the user.
    ///   - dismissing: Dismissal strategy. Defaults to `.after(duration: 0.6)`.
    ///   - completion: Optional callback fired after the toast is dismissed.
    public init(_ message: String, dismissing: Dismissing = .after(duration: 0.6), completion: Completion? = nil) {
        self.message = message
        self.dismissing = dismissing
        self.completion = completion
    }
}

// MARK: ExpressibleByStringLiteral

extension Toast: ExpressibleByStringLiteral {
    /// Lets call sites build a default-dismiss toast directly from a string
    /// literal, e.g. `input.fromController.toastSubject.send("Saved")`.
    public init(stringLiteral message: String) {
        self.init(message)
    }
}

// MARK: - Toast + Presentation

public extension Toast {
    /// Presents the toast on `navigationController` (any UIViewController will
    /// do, the parameter is named for the typical use case).
    ///
    /// The auto-dismiss path schedules the dismiss via
    /// ``Clock/schedule(after:execute:)`` — pass an immediate clock in tests,
    /// the production ``MainQueueClock`` in production. The package itself
    /// does not own a DI container, so the `clock` parameter is the only
    /// acceptable way to inject delayed dispatch here.
    ///
    /// ## Example — present a toast directly (rare; prefer `toastSubject`)
    ///
    /// ```swift
    /// let toast = Toast("Saved", dismissing: .after(duration: 1.0))
    /// toast.present(using: self, clock: MainQueueClock())
    /// ```
    ///
    /// - Parameters:
    ///   - navigationController: The host view controller. The toast is
    ///     presented modally on top of this.
    ///   - clock: The ``Clock`` used to schedule auto-dismiss.
    ///   - dismissedCompletion: Optional callback invoked after dismissal —
    ///     overrides any `completion` supplied at toast construction time.
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
            // Both `Clock` and the closure are `@MainActor`, so capturing
            // `alert` (UIAlertController) and `dismissedCompletion` (a plain
            // non-Sendable closure) is fine — no actor crossing happens.
            clock.schedule(after: duration) {
                alert.dismiss(animated: true, completion: dismissedCompletion)
            }
        }

        navigationController.present(alert, animated: true, completion: nil)
    }
}
