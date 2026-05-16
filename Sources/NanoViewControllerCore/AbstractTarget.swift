// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import Foundation

/// `@objc`-callable target/action shim that forwards UIKit selector callbacks
/// (e.g. `UIBarButtonItem` taps) into a Combine `PassthroughSubject`.
///
/// UIKit's classic target/action API requires a real `target` object and a
/// `Selector`. Combine wants a publisher. `AbstractTarget` is the thin object
/// that bridges the two: it exposes the `@objc` ``pressed()`` method UIKit can
/// call, and it forwards each invocation through a ``Combine/PassthroughSubject``
/// the rest of the app subscribes to.
///
/// ``NanoViewController`` keeps two long-lived `AbstractTarget` instances —
/// one each for the left and right navigation bar buttons — and exposes the
/// matching publishers to ViewModels via ``InputFromController``.
///
/// ## Why is this its own class instead of a closure?
///
/// `target/action` has to point at an `@objc`-visible method on a real object;
/// you cannot pass a Swift closure as the target. Wrapping the subject in a
/// dedicated class keeps the bridging code in one place and avoids polluting
/// every UIViewController subclass with `@objc` glue.
///
/// ## Example — wiring a custom button to a Combine pipeline
///
/// ```swift
/// import Combine
/// import NanoViewControllerCore
/// import UIKit
///
/// final class FloatingActionButton: UIButton {
///     // Subject that downstream code subscribes to.
///     private let tapSubject = PassthroughSubject<Void, Never>()
///     // The @objc target UIKit calls on tap.
///     private lazy var target = AbstractTarget(triggerSubject: tapSubject)
///
///     /// Public publisher of taps.
///     var tapPublisher: AnyPublisher<Void, Never> {
///         tapSubject.eraseToAnyPublisher()
///     }
///
///     override init(frame: CGRect) {
///         super.init(frame: frame)
///         addTarget(target, action: #selector(AbstractTarget.pressed), for: .touchUpInside)
///     }
///
///     @available(*, unavailable)
///     required init?(coder _: NSCoder) { interfaceBuilderSucks }
/// }
///
/// // Usage:
/// let fab = FloatingActionButton()
/// fab.tapPublisher
///     .sink { print("tapped") }
///     .store(in: &cancellables)
/// ```
///
/// In normal app code you'll never need to build one of these directly —
/// ``NanoViewController`` already exposes
/// ``NanoViewController/leftBarButtonAbstractTarget`` and
/// ``NanoViewController/rightBarButtonAbstractTarget`` for navigation bar
/// buttons, and pure Combine extensions on `UIControl` (see
/// `UIControl+Publisher.swift`) cover regular controls.
///
/// `@MainActor` because UIKit dispatches target/action selectors on the main
/// thread.
@MainActor
public class AbstractTarget {
    /// Subject the ``pressed()`` selector pushes into.
    ///
    /// `unowned` because the owning controller (which also holds the subject)
    /// outlives this target, so a strong reference would just be redundant.
    /// Holding the subject `unowned` (rather than `weak`) gives a hard crash if
    /// the assumed lifetime ever inverts — useful for catching wiring errors
    /// during development.
    private unowned let triggerSubject: PassthroughSubject<Void, Never>

    /// Designated initialiser — captures the subject this target forwards into.
    ///
    /// - Parameter triggerSubject: The subject every selector call should push
    ///   a `()` value into. Typically owned by a `NanoViewController`.
    public init(triggerSubject: PassthroughSubject<Void, Never>) {
        self.triggerSubject = triggerSubject
    }

    /// `@objc` entry point UIKit invokes via `#selector(AbstractTarget.pressed)`.
    ///
    /// Forwards a `Void` value through the subject. Always runs on the main
    /// thread because UIKit's target/action dispatch is main-thread-only.
    @objc public func pressed() {
        triggerSubject.send(())
    }
}
