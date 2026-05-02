// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// Marker protocol — ``AbstractSceneView`` subclasses opt in to enable a
/// `UIRefreshControl` on their scroll/table view.
///
/// The presence of conformance is the entire signal; no methods are required.
/// `AbstractSceneView` checks `self is PullToRefreshCapable` during setup and:
///
///   * enables vertical bounce on the scroll view,
///   * installs ``AbstractSceneView/refreshControl`` on the scroll view,
///   * exposes ``isRefreshingBinder``, ``pullToRefreshTitleBinder``, and
///     ``pullToRefreshTriggerPublisher`` via a protocol extension on
///     `PullToRefreshCapable where Self: AbstractSceneView`.
///
/// ## Example — enabling pull-to-refresh on a stack-based scene
///
/// ```swift
/// final class HomeView:
///     BaseScrollableStackViewOwner,
///     ContentViewProvider,
///     PullToRefreshCapable                  // <- the entire opt-in
/// {
///     // …
///     var inputFromView: HomeInputFromView {
///         HomeInputFromView(pullToRefresh: pullToRefreshTriggerPublisher)
///     }
///     func populate(with output: HomeViewModel.OutputVM) -> [AnyCancellable] {
///         [output.isLoading --> isRefreshingBinder]
///     }
/// }
/// ```
public protocol PullToRefreshCapable {}
