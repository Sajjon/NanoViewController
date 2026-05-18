// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import NanoViewControllerCore
import UIKit

public extension NanoViewController {
    /// Installs `barButtonContent` as the navigation item's *right* bar
    /// button, wiring its tap to the controller's
    /// ``rightBarButtonAbstractTarget`` (which in turn pushes to
    /// ``rightBarButtonSubject``, exposed to the ViewModel as
    /// ``InputFromController/rightBarButtonTrigger``).
    ///
    /// Use directly when imperatively setting a bar button (rare). Most
    /// scenes either:
    ///
    ///   * provide ``ControllerConfig/rightBarButton`` for static one-shot
    ///     installation in `viewDidLoad`, or
    ///   * push to ``InputFromController/rightBarButtonContentSubject`` — for
    ///     dynamic content that changes over time (e.g. enable/disable based
    ///     on form validity).
    ///
    /// ## Example — imperative use from a custom subclass
    ///
    /// ```swift
    /// final class CustomScene: NanoViewController<MyView>, ControllerConfigProviding {
    ///     static let config = ControllerConfig(title: "Custom")
    ///
    ///     override func viewDidLoad() {
    ///         super.viewDidLoad()
    ///         setRightBarButtonUsing(content: BarButtonContent(system: .add))
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter barButtonContent: The content (text/image/system) to install.
    func setRightBarButtonUsing(content barButtonContent: BarButtonContent) {
        let item = barButtonContent.makeBarButtonItem(
            target: rightBarButtonAbstractTarget,
            selector: #selector(AbstractTarget.pressed)
        )
        navigationItem.rightBarButtonItem = item
    }

    /// Mirror of ``setRightBarButtonUsing(content:)`` for the *left* bar
    /// button. See that method's documentation for the wiring chain.
    ///
    /// - Parameter barButtonContent: The content (text/image/system) to install.
    func setLeftBarButtonUsing(content barButtonContent: BarButtonContent) {
        let item = barButtonContent.makeBarButtonItem(
            target: leftBarButtonAbstractTarget,
            selector: #selector(AbstractTarget.pressed)
        )
        navigationItem.leftBarButtonItem = item
    }
}
