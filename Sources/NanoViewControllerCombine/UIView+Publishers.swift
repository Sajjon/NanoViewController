// MIT License — Copyright (c) 2018-2026 Open Zesame

import UIKit

public extension UIView {
    /// Binder driving the *negated* `isHidden` state — i.e. `true` shows,
    /// `false` hides.
    var isVisibleBinder: Binder<Bool> {
        Binder(self) { view, isVisible in
            view.isHidden = !isVisible
        }
    }
}

public extension UIImageView {
    /// Binder driving the image view's `image`.
    var imageBinder: Binder<UIImage?> {
        Binder(self) { imageView, image in
            imageView.image = image
        }
    }
}

public extension UIActivityIndicatorView {
    /// Binder driving `startAnimating()` / `stopAnimating()` on each `Bool`.
    ///
    /// Pairs naturally with `ActivityIndicator.asPublisher()` so an in-flight
    /// publisher drives the spinner directly:
    ///
    ///     activity.asPublisher() --> spinner.isAnimatingBinder
    ///
    /// `UIActivityIndicatorView.hidesWhenStopped` defaults to `true`, so the
    /// spinner also disappears when the binder writes `false`.
    var isAnimatingBinder: Binder<Bool> {
        Binder(self) { spinner, isAnimating in
            if isAnimating {
                spinner.startAnimating()
            } else {
                spinner.stopAnimating()
            }
        }
    }
}
