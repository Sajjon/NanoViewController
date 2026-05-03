// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import NanoViewControllerCore
import UIKit

/// Common ancestor of every screen-level `UIViewController` in apps using
/// the package.
///
/// Owns the bar-button-tap pipelines that ``SceneController`` exposes to
/// view-models through ``InputFromController``. Concretely:
///
///   * ``rightBarButtonSubject`` / ``leftBarButtonSubject`` — the publisher
///     side, fired when the bar button is pressed.
///   * ``rightBarButtonAbstractTarget`` / ``leftBarButtonAbstractTarget`` —
///     the `@objc` target/action bridge UIKit can call as a selector and that
///     internally pushes `()` into the matching subject.
///
/// Splitting the two halves like this lets us hand UIKit a real
/// `target/action` pair (which it requires) while presenting the ViewModel
/// layer with a clean Combine publisher.
///
/// ## Example — referencing the bar-button targets from a custom subclass
///
/// You normally don't subclass `AbstractController` directly — you subclass
/// ``SceneController`` (or use it through the ``Scene`` typealias). In the
/// rare case you need a custom controller, here's the wiring:
///
/// ```swift
/// final class CustomScene: AbstractController {
///     override func viewDidLoad() {
///         super.viewDidLoad()
///         // Hook the right bar button into UIKit's target/action.
///         navigationItem.rightBarButtonItem = UIBarButtonItem(
///             title: "Save",
///             style: .done,
///             target: rightBarButtonAbstractTarget,             // <- AbstractTarget
///             action: #selector(AbstractTarget.pressed)         // <- pushes Void
///         )
///         // Subscribe to taps as a Combine publisher.
///         rightBarButtonSubject
///             .sink { print("save tapped") }
///             .store(in: &cancellables)
///     }
///
///     private var cancellables = Set<AnyCancellable>()
/// }
/// ```
open class AbstractController: UIViewController {
    /// Subject fired every time the navigation-item *right* bar button is
    /// pressed. Forwarded to the ViewModel as
    /// ``InputFromController/rightBarButtonTrigger``.
    public let rightBarButtonSubject = PassthroughSubject<Void, Never>()

    /// Subject fired every time the navigation-item *left* bar button is
    /// pressed. Forwarded to the ViewModel as
    /// ``InputFromController/leftBarButtonTrigger``.
    public let leftBarButtonSubject = PassthroughSubject<Void, Never>()

    /// `@objc` target object UIKit invokes for the right bar button's action
    /// selector.
    ///
    /// Lazy because it captures ``rightBarButtonSubject``, which must be
    /// initialised first.
    public lazy var rightBarButtonAbstractTarget = AbstractTarget(triggerSubject: rightBarButtonSubject)

    /// `@objc` target object UIKit invokes for the left bar button's action
    /// selector.
    ///
    /// Lazy because it captures ``leftBarButtonSubject``, which must be
    /// initialised first.
    public lazy var leftBarButtonAbstractTarget = AbstractTarget(triggerSubject: leftBarButtonSubject)

    /// Default initializer forwards to `UIViewController` with the standard
    /// programmatic-only `(nibName: nil, bundle: nil)` pair.
    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    /// Designated `nibName/bundle` initializer kept available for subclasses
    /// that want to forward storyboard/Xib paths through. The package itself
    /// never uses this path.
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    /// Unavailable — Interface Builder is not supported. Traps to enforce the
    /// programmatic-only invariant.
    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }
}

extension AbstractController {
    /// Default `description` is the runtime class name — handy in logs to
    /// identify the concrete `SceneController<…>` specialisation without an
    /// inheritance dance.
    override open var description: String {
        "\(type(of: self))"
    }
}
