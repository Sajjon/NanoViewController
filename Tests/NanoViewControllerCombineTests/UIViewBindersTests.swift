// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

@testable import NanoViewControllerCombine
import UIKit
import XCTest

/// Tests for `UIActivityIndicatorView.isAnimatingBinder` (start/stop both
/// branches). `UIView.isVisibleBinder` and `UIImageView.imageBinder` are
/// already exercised by `BinderTests`; this file fills in the remaining
/// branch in `UIView+Publishers.swift`.
@MainActor
final class UIViewBindersTests: XCTestCase {
    func test_uiActivityIndicatorView_isAnimatingBinder_startsAndStops() {
        let spinner = UIActivityIndicatorView(style: .medium)
        XCTAssertFalse(spinner.isAnimating)

        spinner.isAnimatingBinder.on(true)
        XCTAssertTrue(spinner.isAnimating)

        spinner.isAnimatingBinder.on(false)
        XCTAssertFalse(spinner.isAnimating)
    }
}
