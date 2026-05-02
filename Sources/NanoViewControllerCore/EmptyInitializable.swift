// MIT License — Copyright (c) 2018-2026 Open Zesame

import Foundation

/// Marker protocol asserting "this type can be constructed with no arguments".
///
/// Used by `SceneController` to instantiate the root content view via
/// `(View.self as EmptyInitializable.Type).init()`. Declaring conformance is
/// effectively free for any type whose `init()` is non-failable.
///
/// `@MainActor` because every conformer in this package is a UIView subclass
/// (which becomes `@MainActor` in the iOS 26 SDK). Marking the protocol
/// `@MainActor` keeps UIView conformances valid under Swift 6 strict
/// concurrency.
@MainActor
public protocol EmptyInitializable {
    /// No-argument initialiser the harness uses to spin up an instance.
    init()
}
