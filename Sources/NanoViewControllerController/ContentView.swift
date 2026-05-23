// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import NanoViewControllerCore
import UIKit

/// A concrete `UIView` subclass that also conforms to ``ViewModelled`` —
/// i.e. a view that knows how to construct itself empty
/// (``EmptyInitializable``) and how to bind to its associated ViewModel via
/// `populate(with:)` and `inputFromView`.
///
/// ``NanoViewController`` is parameterised on this typealias so the same generic
/// glue can host any `(UIView, ViewModelled)` pair without each scene having
/// to declare its view/model relationship repeatedly.
///
/// ## Example — declaring a `ContentView` from scratch
///
/// ```swift
/// import Combine
/// import NanoViewControllerController
/// import NanoViewControllerCombine
/// import NanoViewControllerSceneViews
/// import UIKit
///
/// final class WelcomeView: BaseScrollableStackViewOwner, ContentViewProvider {
///     typealias ViewModel = WelcomeViewModel
///
///     // MARK: Subviews
///     private let titleLabel = UILabel()
///     fileprivate let signUpButton = UIButton(type: .system)
///     fileprivate let haveAccountButton = UIButton(type: .system)
///
///     func makeContentView() -> UIView {
///         let stack = UIStackView(arrangedSubviews: [titleLabel, signUpButton, haveAccountButton])
///         stack.axis = .vertical
///         stack.spacing = 16
///         return stack
///     }
///
///     // MARK: ViewModelled
///     var inputFromView: WelcomeViewModel.Input.FromView {
///         WelcomeView.InputFromView(
///             userPressedSignUp:      signUpButton.tapPublisher,
///             userPressedHaveAccount: haveAccountButton.tapPublisher
///         )
///     }
///
///     func populate(with publishers: WelcomeViewModel.Publishers) -> [AnyCancellable] {
///         publishers.title --> titleLabel
///     }
/// }
///
/// // Now WelcomeView fits the ContentView typealias and can be hosted by
/// // NanoViewController<WelcomeView> directly.
/// ```
public typealias ContentView = UIView & ViewModelled
