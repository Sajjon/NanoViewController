// MIT License — Copyright (c) 2018-2026 Open Zesame

import UIKit

/// Opt-in protocol for views that produce their own content view (typically
/// a composed `UIStackView`).
///
/// Used by container views like ``BaseScrollableStackViewOwner`` to ask the
/// conforming subclass: "what goes inside?" — i.e. to obtain the seat that
/// goes inside the scroll view.
///
/// ## Example — typical stack-based content
///
/// ```swift
/// final class SignUpView: BaseScrollableStackViewOwner, ContentViewProvider {
///     private let titleLabel = UILabel()
///     private let usernameField = UITextField()
///     private let passwordField = UITextField()
///     private let submitButton = UIButton(type: .system)
///
///     func makeContentView() -> UIView {
///         let stack = UIStackView(arrangedSubviews: [
///             titleLabel,
///             usernameField,
///             passwordField,
///             submitButton,
///         ])
///         stack.axis = .vertical
///         stack.spacing = 16
///         stack.layoutMargins = .init(top: 24, left: 24, bottom: 24, right: 24)
///         stack.isLayoutMarginsRelativeArrangement = true
///         return stack
///     }
///     // … inputFromView, populate(with:)
/// }
/// ```
public protocol ContentViewProvider {
    /// Construct and return the content view to seat inside the container.
    ///
    /// Called once during composition; the returned view is owned by the
    /// caller. Use this to assemble a `UIStackView` (the common case), a
    /// custom `UIView` subclass, or any composition you want.
    ///
    /// - Returns: The view to seat inside the host's scroll view.
    func makeContentView() -> UIView
}
