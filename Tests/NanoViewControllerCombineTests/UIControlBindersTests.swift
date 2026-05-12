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
        // ARRANGE
        let control = UIControl()
        XCTAssertTrue(control.isEnabled)

        // ACT
        control.isEnabledBinder.on(false)

        // ASSERT
        XCTAssertFalse(control.isEnabled)

        // ACT
        control.isEnabledBinder.on(true)

        // ASSERT
        XCTAssertTrue(control.isEnabled)
    }

    func test_becomeFirstResponderBinder_doesNotCrash() {
        // ARRANGE
        // Without a window/keyWindow, becomeFirstResponder() returns false
        // — the test's purpose is to cover the binder's closure body.
        let textField = UITextField()

        // ACT
        textField.becomeFirstResponderBinder.on(())

        // ASSERT
        // Reaching this line means the binder body did not trap.
    }

    func test_uiLabel_textBinder_writesText() {
        // ARRANGE
        let label = UILabel()

        // ACT
        label.textBinder.on("hello")

        // ASSERT
        XCTAssertEqual(label.text, "hello")

        // ACT
        label.textBinder.on(nil)

        // ASSERT
        XCTAssertNil(label.text)
    }

    func test_uiButton_titleBinder_setsTitleForState() {
        // ARRANGE
        let button = UIButton(type: .system)

        // ACT
        button.titleBinder(for: .normal).on("Normal")
        button.titleBinder(for: .disabled).on("Disabled")

        // ASSERT
        XCTAssertEqual(button.title(for: .normal), "Normal")
        XCTAssertEqual(button.title(for: .disabled), "Disabled")
    }
}
