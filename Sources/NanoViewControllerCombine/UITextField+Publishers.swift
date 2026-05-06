// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import UIKit

public extension UITextField {
    /// Binder for the placeholder text.
    ///
    /// ## Example
    ///
    /// ```swift
    /// output.usernameHint --> usernameField.placeholderBinder
    /// ```
    var placeholderBinder: Binder<String?> {
        Binder(self) { $0.placeholder = $1 }
    }

    /// Write text from ViewModel output.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Reset the field after a successful submit.
    /// output.didSubmit.map { _ in "" } --> usernameField.textBinder
    /// ```
    var textBinder: Binder<String?> {
        Binder(self) { $0.text = $1 }
    }

    /// Publisher of text changes; emits the current text immediately, then
    /// forwards every change via `textDidChangeNotification`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// final class SignUpView: BaseScrollableStackViewOwner, ContentViewProvider {
    ///     fileprivate let usernameField = UITextField()
    ///
    ///     var inputFromView: SignUpInputFromView {
    ///         SignUpInputFromView(
    ///             username:     usernameField.textPublisher.orEmpty,
    ///             password:     passwordField.textPublisher.orEmpty,
    ///             signUpTapped: primaryButton.tapPublisher
    ///         )
    ///     }
    /// }
    /// ```
    var textPublisher: AnyPublisher<String?, Never> {
        Publishers.Merge(
            Just(text),
            NotificationCenter.default
                .publisher(for: UITextField.textDidChangeNotification, object: self)
                .map { ($0.object as? UITextField)?.text }
        )
        .eraseToAnyPublisher()
    }

    /// `true` while the field is the first responder, `false` after it
    /// resigns.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Highlight the active field with a coloured underline.
    /// usernameField.isEditingPublisher
    ///     .map { $0 ? UIColor.systemBlue : .systemGray }
    ///     .sink { [weak self] in self?.underline.backgroundColor = $0 }
    ///     .store(in: &cancellables)
    /// ```
    var isEditingPublisher: AnyPublisher<Bool, Never> {
        publisher(for: .editingDidBegin).map { _ in true }
            .merge(with: publisher(for: .editingDidEnd).map { _ in false })
            .eraseToAnyPublisher()
    }

    /// Fires once each time the user finishes editing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Validate-on-blur:
    /// usernameField.didEndEditingPublisher
    ///     .withLatestFrom(usernameField.textPublisher.orEmpty)
    ///     .map { Validator.validateUsername($0) }
    ///     .sink { [weak self] result in self?.applyValidation(result) }
    ///     .store(in: &cancellables)
    /// ```
    var didEndEditingPublisher: AnyPublisher<Void, Never> {
        isEditingPublisher.filter { !$0 }.mapToVoid().eraseToAnyPublisher()
    }
}

public extension UITextView {
    /// Write text from ViewModel output.
    ///
    /// Note `UITextView.text` is non-optional, so this binder is `Binder<String>`
    /// (unlike ``UIKit/UITextField/textBinder`` which is `Binder<String?>`).
    var textBinder: Binder<String> {
        Binder(self) { $0.text = $1 }
    }

    /// Fires when the text view becomes the first responder.
    ///
    /// ## Example
    ///
    /// ```swift
    /// noteTextView.didBeginEditingPublisher
    ///     .sink { [weak self] in self?.scrollToTextView() }
    ///     .store(in: &cancellables)
    /// ```
    var didBeginEditingPublisher: AnyPublisher<Void, Never> {
        NotificationCenter.default
            .publisher(for: UITextView.textDidBeginEditingNotification, object: self)
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    /// Publisher mirroring ``UIKit/UITextField/textPublisher`` for text views.
    ///
    /// ## Example
    ///
    /// ```swift
    /// noteTextView.textPublisher.orEmpty
    ///     .map { $0.count }
    ///     --> characterCountLabel.textBinder.contramap(String.init)
    /// ```
    var textPublisher: AnyPublisher<String?, Never> {
        Publishers.Merge(
            Just(text),
            NotificationCenter.default
                .publisher(for: UITextView.textDidChangeNotification, object: self)
                .map { ($0.object as? UITextView)?.text }
        )
        .eraseToAnyPublisher()
    }

    /// `true`/`false` editing-state publisher for text views.
    var isEditingPublisher: AnyPublisher<Bool, Never> {
        NotificationCenter.default
            .publisher(for: UITextView.textDidBeginEditingNotification, object: self)
            .map { _ in true }
            .merge(
                with: NotificationCenter.default
                    .publisher(for: UITextView.textDidEndEditingNotification, object: self)
                    .map { _ in false }
            )
            .eraseToAnyPublisher()
    }

    /// `true` whenever the text view is scrolled to within `yThreshold * excess`
    /// of the bottom.
    ///
    /// `yThreshold` defaults to `0.98` (i.e. fires once you're within 2% of the
    /// bottom). When the content fits inside the view (no scroll possible),
    /// the publisher emits `true`.
    ///
    /// ## Example — show "scroll for more" indicator while the user is near
    /// the bottom of a long terms-of-service text view:
    ///
    /// ```swift
    /// termsTextView.isNearBottomPublisher()
    ///     .map { !$0 }                      // show the chevron when NOT near the bottom
    ///     .sink { [weak chevron] in chevron?.isHidden = !$0 }
    ///     .store(in: &cancellables)
    /// ```
    func isNearBottomPublisher(yThreshold: CGFloat = 0.98) -> AnyPublisher<Bool, Never> {
        publisher(for: \.contentOffset)
            .map { [weak self] _ -> Bool in
                guard let self else { return false }
                let excess = contentSize.height - frame.height
                guard excess > 0 else { return true }
                return contentOffset.y >= yThreshold * excess
            }
            .eraseToAnyPublisher()
    }

    /// Edge-triggered variant of ``isNearBottomPublisher(yThreshold:)``.
    ///
    /// Emits each time the user *crosses* the threshold from "not near" to
    /// "near"; doesn't re-emit while the user keeps scrolling near the bottom.
    ///
    /// ## Example — gate a "Continue" button on having scrolled to the
    /// bottom of legal copy:
    ///
    /// ```swift
    /// termsTextView.didScrollNearBottomPublisher()
    ///     .first()
    ///     .map { _ in true }
    ///     --> continueButton.isEnabledBinder
    /// ```
    func didScrollNearBottomPublisher(yThreshold: CGFloat = 0.98) -> AnyPublisher<Void, Never> {
        isNearBottomPublisher(yThreshold: yThreshold).filter { $0 }.mapToVoid().eraseToAnyPublisher()
    }
}
