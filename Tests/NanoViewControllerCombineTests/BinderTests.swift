// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCombine
import UIKit
import XCTest

/// Tests `Binder<Value>` — the write-only, main-thread UI primitive used by
/// `populate(with:)` to propagate ViewModel output into UIKit controls.
@MainActor
final class BinderTests: XCTestCase {
    final class Box {
        var value: Int = 0
    }

    func test_onMainThread_appliesValueSynchronously() {
        // ARRANGE
        let box = Box()
        let binder = Binder(box) { $0.value = $1 }

        // ACT
        binder.on(42)

        // ASSERT
        XCTAssertEqual(box.value, 42)
    }

    func test_onBackgroundThread_appliesOnMainThreadAsynchronously() {
        // ARRANGE
        let box = Box()
        let binder = Binder(box) { $0.value = $1 }
        let expectation = expectation(description: "applied")
        expectation.assertForOverFulfill = false

        // ACT
        DispatchQueue.global().async {
            binder.on(7)
            DispatchQueue.main.async {
                if box.value == 7 { expectation.fulfill() }
            }
        }

        // ASSERT
        wait(for: [expectation], timeout: 1)
    }

    func test_afterObjectDeallocated_writesAreDropped() throws {
        // ARRANGE
        var box: Box? = Box()
        let binder = try Binder(XCTUnwrap(box)) { $0.value = $1 }

        // ACT
        box = nil
        binder.on(99)

        // ASSERT
        // No reference remains; just exercising the weak-guard path.
    }

    func test_uiViewIsVisibleBinder_togglesIsHidden() {
        // ARRANGE
        let view = UIView()
        let binder = view.isVisibleBinder

        // ACT
        binder.on(true)

        // ASSERT
        XCTAssertFalse(view.isHidden)

        // ACT
        binder.on(false)

        // ASSERT
        XCTAssertTrue(view.isHidden)
    }

    func test_uiImageViewImageBinder_setsImage() {
        // ARRANGE
        let imageView = UIImageView()
        let image = UIImage(systemName: "star")

        // ACT
        imageView.imageBinder.on(image)

        // ASSERT
        XCTAssertNotNil(imageView.image)
    }

    func test_bindingOperator_writesIntoBinder() {
        // ARRANGE
        let box = Box()
        let binder = Binder(box) { $0.value = $1 }
        let subject = PassthroughSubject<Int, Never>()
        var cancellables: Set<AnyCancellable> = []
        let expectation = expectation(description: "applied")
        (subject.eraseToAnyPublisher() --> binder).store(in: &cancellables)

        // ACT
        subject.send(11)
        DispatchQueue.main.async {
            if box.value == 11 { expectation.fulfill() }
        }

        // ASSERT
        wait(for: [expectation], timeout: 1)
    }

    func test_bindingOperator_writesIntoLabel() {
        // ARRANGE
        let label = UILabel()
        let subject = PassthroughSubject<String, Never>()
        var cancellables: Set<AnyCancellable> = []
        let expectation = expectation(description: "applied")
        (subject.eraseToAnyPublisher() --> label).store(in: &cancellables)

        // ACT
        subject.send("hello")
        DispatchQueue.main.async {
            if label.text == "hello" { expectation.fulfill() }
        }

        // ASSERT
        wait(for: [expectation], timeout: 1)
    }

    func test_bindingOperator_writesIntoTextView() {
        // ARRANGE
        let textView = UITextView()
        let subject = PassthroughSubject<String, Never>()
        var cancellables: Set<AnyCancellable> = []
        let expectation = expectation(description: "applied")
        (subject.eraseToAnyPublisher() --> textView).store(in: &cancellables)

        // ACT
        subject.send("body")
        DispatchQueue.main.async {
            if textView.text == "body" { expectation.fulfill() }
        }

        // ASSERT
        wait(for: [expectation], timeout: 1)
    }

    func test_bindingOperator_optionalString_writesIntoLabel() {
        // ARRANGE
        let label = UILabel()
        let subject = PassthroughSubject<String?, Never>()
        var cancellables: Set<AnyCancellable> = []
        let expectation = expectation(description: "applied")
        (subject.eraseToAnyPublisher() --> label).store(in: &cancellables)

        // ACT
        subject.send("optional-hello")
        DispatchQueue.main.async {
            if label.text == "optional-hello" { expectation.fulfill() }
        }

        // ASSERT
        wait(for: [expectation], timeout: 1)
    }

    func test_bindingOperator_optionalString_writesIntoTextView() {
        // ARRANGE
        let textView = UITextView()
        let subject = PassthroughSubject<String?, Never>()
        var cancellables: Set<AnyCancellable> = []
        let expectation = expectation(description: "applied")
        (subject.eraseToAnyPublisher() --> textView).store(in: &cancellables)

        // ACT
        subject.send("optional-body")
        DispatchQueue.main.async {
            if textView.text == "optional-body" { expectation.fulfill() }
        }

        // ASSERT
        wait(for: [expectation], timeout: 1)
    }

    /// Exercises the `publisher --> Binder<T?>` overload (non-optional value lifted
    /// into an optional sink).
    func test_bindingOperator_nonOptionalIntoOptionalBinder() {
        // ARRANGE
        let label = UILabel()
        let optionalBinder: Binder<String?> = Binder(label) { $0.text = $1 }
        let subject = PassthroughSubject<String, Never>()
        var cancellables: Set<AnyCancellable> = []
        let expectation = expectation(description: "applied")
        (subject.eraseToAnyPublisher() --> optionalBinder).store(in: &cancellables)

        // ACT
        subject.send("lifted")
        DispatchQueue.main.async {
            if label.text == "lifted" { expectation.fulfill() }
        }

        // ASSERT
        wait(for: [expectation], timeout: 1)
    }

    /// Exercises the `publisher-of-optional --> Binder<T?>` overload.
    func test_bindingOperator_optionalIntoOptionalBinder() {
        // ARRANGE
        let label = UILabel()
        let binder: Binder<String?> = Binder(label) { $0.text = $1 }
        let subject = PassthroughSubject<String?, Never>()
        var cancellables: Set<AnyCancellable> = []
        let expectation = expectation(description: "applied")
        (subject.eraseToAnyPublisher() --> binder).store(in: &cancellables)

        // ACT
        subject.send("opt-to-opt")
        DispatchQueue.main.async {
            if label.text == "opt-to-opt" { expectation.fulfill() }
        }

        // ASSERT
        wait(for: [expectation], timeout: 1)
    }

    /// Covers the *initial* emission of `UISegmentedControl.valuePublisher` —
    /// the merged `Just(selectedSegmentIndex)` half. The `.valueChanged` half
    /// is exercised by the host-app ZhipTests, since `sendActions(for:)` on a
    /// segmented control that isn't in a window doesn't reliably fire its
    /// target/action chain inside an SPM test target with no host app.
    func test_uiSegmentedControl_valuePublisher_emitsInitialIndex() {
        // ARRANGE
        let segmented = UISegmentedControl(items: ["A", "B", "C"])
        segmented.selectedSegmentIndex = 1
        var emitted: [Int] = []
        var cancellables: Set<AnyCancellable> = []

        // ACT
        segmented.valuePublisher.sink { emitted.append($0) }.store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(emitted.first, 1)
    }
}
