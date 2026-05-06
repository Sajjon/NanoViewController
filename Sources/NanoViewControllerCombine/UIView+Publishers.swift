// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import UIKit

public extension UIView {
    /// Binder driving the *negated* `isHidden` state — i.e. `true` shows,
    /// `false` hides.
    ///
    /// The negation is intentional: `Bool` publishers in ViewModels are
    /// almost always written from the user-readable side (`isVisible`,
    /// `isLoading`, `canSubmit`), and double-negating to drive `isHidden`
    /// reads worse. Bind a positive-sense publisher and let this binder
    /// handle the flip.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // ViewModel exposes "is loading" — we want the spinner *visible* when loading.
    /// output.isLoading --> spinner.isVisibleBinder
    ///
    /// // For the inverse — hide the form while loading — bind `!isLoading`:
    /// output.isLoading.map { !$0 } --> formStackView.isVisibleBinder
    /// ```
    var isVisibleBinder: Binder<Bool> {
        Binder(self) { view, isVisible in
            view.isHidden = !isVisible
        }
    }
}

public extension UIImageView {
    /// Binder driving the image view's `image`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Drive avatar from a ViewModel publisher.
    /// output.avatarImage --> avatarView.imageBinder
    ///
    /// // Reset on a Void pulse:
    /// output.didLogout.map { _ in nil } --> avatarView.imageBinder
    /// ```
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
