// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine

/// One-way bridge between ViewModels (which decide what happens next) and
/// coordinators (which know how to push/pop/present).
///
/// The ViewModel calls `navigator.next(step)` to declare intent; the coordinator
/// subscribes to `navigator.navigation` to receive those steps and perform the
/// actual UIKit transitions.
///
/// `@unchecked Sendable` so a `BaseCoordinator` (which is `@MainActor` for iOS
/// 26 readiness) can hold a `nonisolated let navigator = Navigator<Step>()`
/// and still satisfy the non-isolated `Navigating` protocol requirement. The
/// underlying `PassthroughSubject` is thread-safe in practice; `NavigationStep`
/// values flow only through `send(_:)`/`sink { }`, not stored mutably.
public final class Navigator<NavigationStep>: @unchecked Sendable {
    /// Internal backing subject. Exposed read-only via `navigation`.
    private let navigationSubject = PassthroughSubject<NavigationStep, Never>()

    /// Erased publisher coordinators subscribe to. Lazy so each `Navigator`
    /// produces the publisher at most once and subsequent subscriptions share it.
    public lazy var navigation: AnyPublisher<NavigationStep, Never> = navigationSubject.eraseToAnyPublisher()

    /// Default initializer.
    public init() {}
}

public extension Navigator {
    /// Emits `step` on `navigation`. Called by ViewModels to request navigation.
    func next(_ step: NavigationStep) {
        navigationSubject.send(step)
    }
}
