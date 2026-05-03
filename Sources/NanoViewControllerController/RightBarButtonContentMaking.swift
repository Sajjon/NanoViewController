// MIT License — Copyright (c) 2018-2026 Open Zesame

import UIKit

/// Low-level opt-in for a screen that wants a custom right bar button.
///
/// Conformers supply a fully-formed ``BarButtonContent`` directly. Apps with a
/// predefined bar-button library typically declare a refinement (see
/// `RightBarButtonMaking` in the original Zhip codebase) that pre-fills
/// ``makeRightContent`` from a typed enum case.
///
/// ## Example — static "Save" button
///
/// ```swift
/// final class EditProfileScene: Scene<EditProfileView>, RightBarButtonContentMaking {
///     static var title: String { "Edit profile" }
///     static var makeRightContent: BarButtonContent {
///         BarButtonContent(title: "Save", style: .done)
///     }
/// }
///
/// // The tap arrives at editProfileVM.input.fromController.rightBarButtonTrigger.
/// ```
///
/// For *dynamic* bar-button content (e.g. an enabled/disabled state that
/// depends on form validity), don't use this protocol — push values into
/// ``InputFromController/rightBarButtonContentSubject`` from the ViewModel
/// instead.
@MainActor
public protocol RightBarButtonContentMaking {
    /// The content to install as the right bar button on `viewDidLoad`.
    static var makeRightContent: BarButtonContent { get }
}

public extension RightBarButtonContentMaking {
    /// Convenience used by ``SceneController/viewDidLoad()`` to install the
    /// right bar button on the supplied controller.
    ///
    /// - Parameter viewController: The controller to install the button on.
    func setRightBarButton(for viewController: AbstractController) {
        viewController.setRightBarButtonUsing(content: Self.makeRightContent)
    }
}

/// Marker protocol — when a ``SceneController`` conforms, the system back
/// chevron is hidden AND the swipe-back gesture is disabled.
///
/// Use on flow-terminating screens (e.g. "wallet created" confirmation) where
/// backing up would re-enter an inconsistent state. The conformance is its
/// own opt-in signal — no method requirements.
///
/// ## Example
///
/// ```swift
/// final class WalletCreatedScene: Scene<WalletCreatedView>, BackButtonHiding {
///     static var title: String { "" }
/// }
///
/// // After this scene appears, the user CANNOT swipe back into the (now-stale)
/// // create-wallet flow — they have to use the explicit "Continue" CTA.
/// ```
@MainActor
public protocol BackButtonHiding {}
