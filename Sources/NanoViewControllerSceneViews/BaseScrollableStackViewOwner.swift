// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerCore
import UIKit

/// ``AbstractSceneView`` specialisation that owns a content view inside a
/// vertical scroll view.
///
/// The content view is built lazily by asking the subclass (which must
/// conform to ``ContentViewProvider``) — typically resulting in a
/// `UIStackView`. This is the most common scene-view base class, used for
/// any "scroll a column of widgets" screen.
///
/// Conforms to ``EmptyInitializable`` so ``SceneController`` can construct it
/// from the `View` generic constraint without consumers having to write a
/// custom factory.
///
/// ## Example — full screen built on top of `BaseScrollableStackViewOwner`
///
/// ```swift
/// import Combine
/// import NanoViewControllerCombine
/// import NanoViewControllerController
/// import NanoViewControllerSceneViews
/// import UIKit
///
/// final class WelcomeView: BaseScrollableStackViewOwner, ContentViewProvider {
///     typealias ViewModel = WelcomeViewModel
///
///     // MARK: Subviews
///     private let titleLabel = UILabel()
///     fileprivate let createButton = UIButton(type: .system)
///     fileprivate let restoreButton = UIButton(type: .system)
///
///     // MARK: ContentViewProvider
///     func makeContentView() -> UIView {
///         titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
///         titleLabel.numberOfLines = 0
///         createButton.setTitle("Create wallet", for: .normal)
///         restoreButton.setTitle("Restore from seed", for: .normal)
///
///         let stack = UIStackView(arrangedSubviews: [titleLabel, createButton, restoreButton])
///         stack.axis = .vertical
///         stack.spacing = 24
///         stack.layoutMargins = .init(top: 60, left: 24, bottom: 24, right: 24)
///         stack.isLayoutMarginsRelativeArrangement = true
///         return stack
///     }
///
///     // MARK: ViewModelled
///     struct InputFromView {
///         let userPressedCreate:  AnyPublisher<Void, Never>
///         let userPressedRestore: AnyPublisher<Void, Never>
///     }
///
///     var inputFromView: InputFromView {
///         InputFromView(
///             userPressedCreate:  createButton.tapPublisher,
///             userPressedRestore: restoreButton.tapPublisher
///         )
///     }
///
///     func populate(with output: WelcomeViewModel.OutputVM) -> [AnyCancellable] {
///         [output.headline --> titleLabel]
///     }
/// }
///
/// // SceneController<WelcomeView> can now host this view directly.
/// typealias WelcomeScene = Scene<WelcomeView>
/// ```
open class BaseScrollableStackViewOwner: AbstractSceneView, EmptyInitializable {
    // MARK: Initialization

    /// ``EmptyInitializable`` entry point — ``SceneController`` constructs
    /// the scene view via `init()`.
    ///
    /// Passes a fresh empty `UIScrollView` to the abstract base, then runs
    /// the local setup chain to seat the content view.
    public required init() {
        super.init(scrollView: UIScrollView(frame: .zero))
        setupBaseScrollableStackViewOwner()
    }

    /// Storyboard init — unsupported, traps to enforce programmatic-only use.
    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }

    /// Lazy content view inside the scroll view.
    ///
    /// Built once via ``makeScrollViewContentView()``; subsequent reads
    /// return the cached instance.
    public lazy var scrollViewContentView: UIView = makeScrollViewContentView()

    /// Builds the content view by asking the subclass (which must conform to
    /// ``ContentViewProvider``).
    ///
    /// Crashes loudly if the conformance is missing — the type system doesn't
    /// enforce it because `BaseScrollableStackViewOwner` itself is not a
    /// `ContentViewProvider`, only its subclasses are.
    open func makeScrollViewContentView() -> UIView {
        guard let contentViewProvider = self as? ContentViewProvider else {
            incorrectImplementation("Self should be ContentViewProvider")
        }
        return contentViewProvider.makeContentView()
    }
}

// MARK: - Private

private extension BaseScrollableStackViewOwner {
    /// Pins the content view inside the scroll view:
    ///
    ///   * matches the scroll view's width (so horizontal scrolling is disabled),
    ///   * is at least as tall as the scroll view (so short content centres),
    ///   * pins top to `contentLayoutGuide.topAnchor` so content can extend
    ///     under the nav bar, and bottom to `keyboardLayoutGuide.topAnchor`
    ///     to **match** the scroll view's own bottom anchor (set in
    ///     ``AbstractSceneView/setupScrollViewConstraints()``).
    ///
    /// The bottom-anchor alignment is load-bearing: if the content view
    /// extended below the scroll view's frame (e.g. by pinning to
    /// `self.bottomAnchor` while the scroll view stops at the safe area),
    /// devices with a home indicator would gain ~34pt of blank scrollable
    /// space at the bottom even when no keyboard is on screen.
    func setupBaseScrollableStackViewOwner() {
        scrollViewContentView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(scrollViewContentView)

        let contentLayoutGuide = scrollView.contentLayoutGuide
        let frameLayoutGuide = scrollView.frameLayoutGuide

        let heightAtLeastFrame = scrollViewContentView.heightAnchor.constraint(
            greaterThanOrEqualTo: frameLayoutGuide.heightAnchor
        )
        heightAtLeastFrame.priority = .defaultHigh

        NSLayoutConstraint.activate([
            scrollViewContentView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
            heightAtLeastFrame,
            scrollViewContentView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            scrollViewContentView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            scrollViewContentView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            scrollViewContentView.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
        ])
    }
}
