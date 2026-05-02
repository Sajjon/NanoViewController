// MIT License — Copyright (c) 2018-2026 Open Zesame

/// Type capable of navigating. Declaring which navigation steps it can perform, by
/// declaring an `associatedtype` named `NavigationStep` which typically is a nested
/// enum.
///
/// `NavigationStep` is constrained to `Sendable` because the navigator's
/// `navigation` publisher is observed from `sinkOnMain` (and other Combine
/// chains crossing actor boundaries). Concrete enums of trivial cases are
/// implicitly `Sendable`; cases that carry payloads should ensure their
/// associated values are `Sendable` too.
public protocol Navigating {
    associatedtype NavigationStep: Sendable
    var navigator: Navigator<NavigationStep> { get }
}
