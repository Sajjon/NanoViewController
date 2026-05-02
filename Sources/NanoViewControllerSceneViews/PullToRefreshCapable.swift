// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// Marker protocol — `AbstractSceneView` subclasses opt in to enable a
/// `UIRefreshControl` on their scroll/table view. The presence of conformance
/// is the entire signal; no methods are required.
///
/// `@MainActor` because conformers are `UIView` subclasses (`@MainActor` in
/// the iOS 26 SDK) and the protocol-extension members touch `UIRefreshControl`.
@MainActor
public protocol PullToRefreshCapable {}
