// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCombine
import UIKit
import XCTest

/// Tests for the binders + helper publishers in
/// `UITextField+Publishers.swift`, covering both the `UITextField` and
/// `UITextView` extensions:
///
///   * binders (`placeholderBinder`, `textBinder`)
///   * `textPublisher` initial emission and `textDidChange` forwarding
///   * `UITextView.isNearBottomPublisher` / `didScrollNearBottomPublisher`
///
/// The `editingDidBegin` / `editingDidEnd` paths on `UIControl` rely on
/// `sendActions(for:)`, which doesn't reliably fire its target/action chain
/// inside an SPM test target with no host app (same caveat as
/// `BinderTests.test_uiSegmentedControl_valuePublisher_…`). We do still
/// subscribe to the `isEditingPublisher` to cover the construction path.
@MainActor
final class UITextFieldPublishersTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - UITextField

    func test_textField_placeholderBinder_writesPlaceholder() {
        let field = UITextField()
        field.placeholderBinder.on("name")
        XCTAssertEqual(field.placeholder, "name")
    }

    func test_textField_textBinder_writesText() {
        let field = UITextField()
        field.textBinder.on("hello")
        XCTAssertEqual(field.text, "hello")
    }

    func test_textField_textPublisher_emitsCurrentTextThenChanges() {
        let field = UITextField()
        field.text = "initial"
        var received: [String?] = []

        field.textPublisher.sink { received.append($0) }.store(in: &cancellables)

        XCTAssertEqual(received, ["initial"])

        field.text = "updated"
        NotificationCenter.default.post(
            name: UITextField.textDidChangeNotification,
            object: field
        )

        XCTAssertEqual(received, ["initial", "updated"])
    }

    func test_textField_isEditingPublisher_subscribes() {
        // Just exercise the construction path. Sending `.editingDidBegin` via
        // `sendActions(for:)` on a UITextField that isn't in a window doesn't
        // reliably fire its target/action chain inside an SPM test target with
        // no host app, so we don't assert on emissions.
        let field = UITextField()
        field.isEditingPublisher.sink { _ in }.store(in: &cancellables)
        field.didEndEditingPublisher.sink { _ in }.store(in: &cancellables)
    }

    // MARK: - UITextView

    func test_textView_textBinder_writesText() {
        let view = UITextView()
        view.textBinder.on("body")
        XCTAssertEqual(view.text, "body")
    }

    func test_textView_textPublisher_emitsCurrentTextThenChanges() {
        let view = UITextView()
        view.text = "initial"
        var received: [String?] = []

        view.textPublisher.sink { received.append($0) }.store(in: &cancellables)
        XCTAssertEqual(received, ["initial"])

        view.text = "updated"
        NotificationCenter.default.post(
            name: UITextView.textDidChangeNotification,
            object: view
        )

        XCTAssertEqual(received, ["initial", "updated"])
    }

    func test_textView_didBeginEditingPublisher_forwardsNotification() {
        let view = UITextView()
        var received = 0

        view.didBeginEditingPublisher.sink { received += 1 }.store(in: &cancellables)
        NotificationCenter.default.post(
            name: UITextView.textDidBeginEditingNotification,
            object: view
        )

        XCTAssertEqual(received, 1)
    }

    func test_textView_isEditingPublisher_forwardsBeginAndEnd() {
        let view = UITextView()
        var received: [Bool] = []

        view.isEditingPublisher.sink { received.append($0) }.store(in: &cancellables)

        NotificationCenter.default.post(
            name: UITextView.textDidBeginEditingNotification,
            object: view
        )
        NotificationCenter.default.post(
            name: UITextView.textDidEndEditingNotification,
            object: view
        )

        XCTAssertEqual(received, [true, false])
    }

    func test_textView_isNearBottomPublisher_returnsTrueWhenContentFits() {
        // Content smaller than the frame ⇒ excess ≤ 0 ⇒ publisher emits true.
        let view = UITextView(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        view.text = "short"
        var received: [Bool] = []

        view.isNearBottomPublisher().sink { received.append($0) }.store(in: &cancellables)

        XCTAssertEqual(received.first, true)
    }

    func test_textView_isNearBottomPublisher_emitsThresholdComparisonWhenContentOverflows() {
        // Force a contentSize that exceeds the frame so the publisher exercises
        // the `return contentOffset.y >= yThreshold * excess` branch (line 172).
        let view = UITextView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        view.contentSize = CGSize(width: 100, height: 1_000)
        view.contentOffset = CGPoint(x: 0, y: 990)

        var received: [Bool] = []
        view.isNearBottomPublisher().sink { received.append($0) }.store(in: &cancellables)

        // Fixed-threshold == 0.98 — at offset 990 of excess 950 we are well past
        // the threshold, so the comparison evaluates true.
        XCTAssertEqual(received.first, true)

        // And once we scroll back to the top, the next emission is false.
        view.contentOffset = .zero
        XCTAssertEqual(received.last, false)
    }

    func test_textView_didScrollNearBottomPublisher_subscribes() {
        // Just exercise the construction path — KVO on `contentOffset` doesn't
        // fire a fresh emission inside this SPM-test environment without a
        // window, so we keep the assertion to "doesn't crash on subscribe".
        let view = UITextView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.didScrollNearBottomPublisher().sink { _ in }.store(in: &cancellables)
    }
}
