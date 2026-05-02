// MIT License — Copyright (c) 2018-2026 Open Zesame

import UIKit

/// Low-level opt-in for a screen that wants a custom left bar button.
///
/// Conformers supply a fully-formed ``BarButtonContent`` directly. Apps with a
/// predefined bar-button library typically declare a refinement (see
/// `LeftBarButtonMaking` in the original Zhip codebase) that pre-fills
/// ``makeLeftContent`` from a typed enum case.
///
/// ``SceneController/viewDidLoad()`` runtime-casts `self as?
/// LeftBarButtonContentMaking`; conformance is the entire opt-in, no method
/// override is required.
///
/// ## Example — static "Cancel" button on a modally-presented scene
///
/// ```swift
/// final class EditProfileScene: Scene<EditProfileView>, LeftBarButtonContentMaking {
///     static var title: String { "Edit profile" }
///     static var makeLeftContent: BarButtonContent { BarButtonContent(system: .cancel) }
/// }
///
/// // The user can now tap Cancel; the tap arrives at
/// // editProfileVM.input.fromController.leftBarButtonTrigger.
/// ```
public protocol LeftBarButtonContentMaking {
    /// The content to install as the left bar button on `viewDidLoad`.
    static var makeLeftContent: BarButtonContent { get }
}

public extension LeftBarButtonContentMaking {
    /// Convenience used by ``SceneController/viewDidLoad()`` to install the
    /// left bar button on the supplied controller without exposing the static
    /// indirection at every call site.
    ///
    /// - Parameter viewController: The controller to install the button on.
    func setLeftBarButton(for viewController: AbstractController) {
        viewController.setLeftBarButtonUsing(content: Self.makeLeftContent)
    }
}
