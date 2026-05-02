// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// Marker protocol asserting "this type can be constructed with no arguments".
///
/// ``SceneController`` instantiates the root content view via
/// `(View.self as EmptyInitializable.Type).init()`. Declaring conformance is
/// effectively free for any type whose `init()` is non-failable — usually a
/// one-line:
///
/// ```swift
/// extension MyContentView: EmptyInitializable {}
/// ```
///
/// or, if you need an explicit `init()`:
///
/// ```swift
/// public required init() {
///     super.init(frame: .zero)
///     setup()
/// }
/// ```
///
/// ## Why a separate protocol?
///
/// A bare `init()` requirement looks unnecessary, but UIKit's class hierarchy
/// makes it surprisingly load-bearing: `UIView`'s designated initialiser is
/// `init(frame:)`, *not* `init()`, so generic code can't simply write
/// `View()`. Declaring `EmptyInitializable` lets the type system carry the
/// "yes, this view promises a no-arg initialiser" guarantee through generic
/// constraints like `View: ContentView` (see ``ContentView``).
///
/// ## Example — a minimal `ContentView` conformer
///
/// ```swift
/// import NanoViewControllerCore
/// import NanoViewControllerSceneViews
/// import UIKit
///
/// /// Scene root. EmptyInitializable so SceneController<View> can build it.
/// final class WelcomeView: BaseScrollableStackViewOwner, ContentViewProvider {
///     // BaseScrollableStackViewOwner already provides `required init()` and
///     // declares EmptyInitializable conformance, so this subclass inherits it.
///
///     func makeContentView() -> UIView {
///         let stack = UIStackView()
///         stack.axis = .vertical
///         stack.spacing = 16
///         stack.addArrangedSubview(headlineLabel)
///         stack.addArrangedSubview(continueButton)
///         return stack
///     }
///
///     // ... ViewModelled conformance fills in the rest
/// }
///
/// // SceneController<WelcomeView> can now construct the view via
/// // (WelcomeView.self as EmptyInitializable.Type).init().
/// ```
public protocol EmptyInitializable {
    /// No-argument initialiser the harness uses to spin up an instance.
    ///
    /// Conformers must guarantee it cannot fail. UIKit-derived types typically
    /// implement it as `init() { super.init(frame: .zero); setup() }`.
    init()
}
