// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import UIKit

public extension UIControl {
    /// Binder that programmatically focuses this control on each `Void` value.
    ///
    /// Bind a `Void` publisher to it whenever you want the field to
    /// auto-focus — typically `viewDidAppear` for a "first field" entry, or
    /// after a successful step that should advance focus.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Focus the username field as soon as the screen appears.
    /// input.fromController.viewDidAppear --> usernameField.becomeFirstResponderBinder
    /// ```
    var becomeFirstResponderBinder: Binder<Void> {
        Binder(self) { control, _ in _ = control.becomeFirstResponder() }
    }

    /// Binder driving the control's `isEnabled` state.
    ///
    /// ## Example
    ///
    /// ```swift
    /// output.canSubmit --> submitButton.isEnabledBinder
    /// ```
    var isEnabledBinder: Binder<Bool> {
        Binder(self) { $0.isEnabled = $1 }
    }

    /// Publisher fired for each `.touchUpInside` event.
    ///
    /// ## Example
    ///
    /// ```swift
    /// final class SignUpView: BaseScrollableStackViewOwner, ContentViewProvider {
    ///     fileprivate let primaryButton = UIButton(type: .system)
    ///
    ///     var inputFromView: SignUpInputFromView {
    ///         SignUpInputFromView(
    ///             signUpTapped: primaryButton.tapPublisher,
    ///             // …
    ///         )
    ///     }
    /// }
    /// ```
    var tapPublisher: AnyPublisher<Void, Never> {
        publisher(for: .touchUpInside).eraseToAnyPublisher()
    }
}

public extension UILabel {
    /// Binder that drives the label's `text`.
    ///
    /// Sugar for `output.title --> titleLabel` (the `String` overload of the
    /// `-->` operator already targets `UILabel.text`); use this binder
    /// directly when you want optional-string semantics or are composing
    /// inside a custom view.
    ///
    /// ## Example
    ///
    /// ```swift
    /// output.errorMessage --> errorLabel.textBinder
    /// ```
    var textBinder: Binder<String?> {
        Binder(self) { $0.text = $1 }
    }
}

public extension UIButton {
    /// Returns a binder that updates the button's title for the given control state.
    ///
    /// ## Example
    ///
    /// ```swift
    /// output.primaryTitle --> primaryButton.titleBinder(for: .normal)
    /// output.disabledHint --> primaryButton.titleBinder(for: .disabled)
    /// ```
    ///
    /// - Parameter state: The `UIControl.State` whose title should be updated.
    /// - Returns: A `Binder<String?>` that writes the title for `state`.
    func titleBinder(for state: UIControl.State) -> Binder<String?> {
        Binder(self) { button, title in
            button.setTitle(title, for: state)
        }
    }
}

public extension UISegmentedControl {
    /// Publisher of the currently-selected segment index.
    ///
    /// Emits the current value immediately on subscription, then forwards
    /// every `.valueChanged` event afterwards. Useful for ViewModels that
    /// need a fresh "what's selected right now" without waiting for the user
    /// to interact.
    ///
    /// ## Example
    ///
    /// ```swift
    /// final class SegmentView: UIView {
    ///     private let segments = UISegmentedControl(items: ["Day", "Week", "Month"])
    ///     // …
    ///     var inputFromView: TimeRangeInputFromView {
    ///         TimeRangeInputFromView(selectedRange: segments.valuePublisher)
    ///     }
    /// }
    /// ```
    var valuePublisher: AnyPublisher<Int, Never> {
        Publishers.Merge(
            Just(selectedSegmentIndex),
            publisher(for: .valueChanged).map { [weak self] _ in self?.selectedSegmentIndex ?? 0 }
        )
        .eraseToAnyPublisher()
    }
}
