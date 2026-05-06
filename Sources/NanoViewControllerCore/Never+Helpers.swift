// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Foundation

/// Stub used in `init?(coder:)` overrides to enforce the package's
/// programmatic-only invariant.
///
/// The codebase does not use Storyboards or XIBs, so the storyboard-decoder
/// initialiser should never be invoked. Marking the override as
/// `@available(*, unavailable)` and trapping inside catches accidental
/// invocations early.
///
/// ## Example
///
/// ```swift
/// final class HomeView: UIView {
///     override init(frame: CGRect) {
///         super.init(frame: frame)
///         setup()
///     }
///
///     @available(*, unavailable)
///     required init?(coder _: NSCoder) {
///         interfaceBuilderSucks      // <- traps with a clear message
///     }
/// }
/// ```
public var interfaceBuilderSucks: Never {
    fatalError("interfaceBuilderSucks")
}

/// Crashes with a descriptive message at code-paths that indicate a programmer
/// error rather than a user-facing failure.
///
/// Use it for invariants that, if violated, mean the build is shipping with a
/// bug — there is no graceful recovery and the only way to learn about it is a
/// loud crash during development.
///
/// ## Example
///
/// ```swift
/// guard let nav = navigationController as? NavigationBarLayoutingNavigationController else {
///     incorrectImplementation(
///         "navigationController should be `NavigationBarLayoutingNavigationController`"
///     )
/// }
/// ```
///
/// - Parameter message: A descriptive message that pinpoints the broken invariant.
/// - Returns: Never returns — `fatalError` halts the program.
public func incorrectImplementation(_ message: CustomStringConvertible) -> Never {
    fatalError("Incorrect implementation - \(message.description)")
}

/// Marker for "abstract" stored properties or methods that subclasses are
/// expected to override.
///
/// Used as the body of a base-class method whose default implementation makes
/// no sense — for example, ``AbstractViewModel/transform(input:)`` and
/// ``BaseCoordinator/start(didStart:)``.
///
/// ## Example
///
/// ```swift
/// open class MyBaseCoordinator<Step>: Coordinating {
///     // Concrete subclasses MUST override this.
///     open func start(didStart _: Completion? = nil) {
///         abstract
///     }
/// }
/// ```
public var abstract: Never {
    fatalError("Override me")
}
