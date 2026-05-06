// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import UIKit

/// Marker-with-payload protocol for views that own a scroll view as part of
/// their composition.
///
/// Lets generic infrastructure (e.g. pull-to-refresh installation) reach the
/// underlying scroll view without knowing the conforming view's full
/// structure. ``AbstractSceneView`` is the standard conformer.
///
/// ## Example — using `ScrollViewOwner` to expose a scrollToTop helper
///
/// ```swift
/// extension ScrollViewOwner {
///     func scrollToTop(animated: Bool = true) {
///         scrollView.setContentOffset(
///             .init(x: 0, y: -scrollView.adjustedContentInset.top),
///             animated: animated
///         )
///     }
/// }
///
/// // Now any AbstractSceneView subclass gets `scrollToTop` for free:
/// homeView.scrollToTop()
/// ```
@MainActor
public protocol ScrollViewOwner {
    /// The owned scroll view — typically the one that hosts the scene's content.
    var scrollView: UIScrollView { get }
}
