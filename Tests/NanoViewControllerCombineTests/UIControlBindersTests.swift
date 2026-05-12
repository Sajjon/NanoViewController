// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCombine
import UIKit
import XCTest

/// Tests for the binders + helper publishers in `UIControl+Publishers.swift`:
///
///   * `UIControl.becomeFirstResponderBinder`
///   * `UIControl.isEnabledBinder`
///   * `UILabel.textBinder`
///   * `UIButton.titleBinder(for:)`
///
/// `UISegmentedControl.valuePublisher`'s initial-emission half is already
/// covered by `BinderTests.test_uiSegmentedControl_valuePublisher_…`; the
/// `.valueChanged` half is host-app-only (per that test's doc-comment).
@MainActor
final class UIControlBindersTests: XCTestCase {
    func test_isEnabledBinder_writesIsEnabled() {
        let control = UIControl()
        XCTAssertTrue(control.isEnabled)

        control.isEnabledBinder.on(false)
        XCTAssertFalse(control.isEnabled)

        control.isEnabledBinder.on(true)
        XCTAssertTrue(control.isEnabled)
    }

    func test_becomeFirstResponderBinder_doesNotCrash() {
        // Without a window/keyWindow, becomeFirstResponder() returns false
        // — the test's purpose is to cover the binder's closure body.
        let textField = UITextField()
        textField.becomeFirstResponderBinder.on(())
    }

    func test_uiLabel_textBinder_writesText() {
        let label = UILabel()
        label.textBinder.on("hello")
        XCTAssertEqual(label.text, "hello")

        label.textBinder.on(nil)
        XCTAssertNil(label.text)
    }

    func test_uiButton_titleBinder_setsTitleForState() {
        let button = UIButton(type: .system)

        button.titleBinder(for: .normal).on("Normal")
        button.titleBinder(for: .disabled).on("Disabled")

        XCTAssertEqual(button.title(for: .normal), "Normal")
        XCTAssertEqual(button.title(for: .disabled), "Disabled")
    }
}
