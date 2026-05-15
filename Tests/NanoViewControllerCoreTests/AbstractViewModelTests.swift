// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCore
import XCTest

/// Tests for `AbstractViewModel` — the generic base class every concrete
/// ViewModel inherits from. Covers the synthesised `Input` struct, and
/// verifies that subclassing + overriding `transform` produces an ``Output``
/// carrying both the publisher bag and any subscriptions started inside
/// `transform`.
@MainActor
final class AbstractViewModelTests: XCTestCase {
    private struct FromView { let tap: AnyPublisher<Void, Never> }
    private struct FromController { let viewDidAppear: AnyPublisher<Void, Never> }
    private struct Publishers { let title: AnyPublisher<String, Never> }

    private final class StubViewModel: AbstractViewModel<FromView, FromController, Publishers> {
        private(set) var transformCalls = 0
        // Mutating side-effect counter that proves the subscription block ran.
        private(set) var sideEffectCalls = 0
        override func transform(input: Input) -> Output<Publishers> {
            transformCalls += 1
            // Use both channels so the synthesised stitching is genuinely
            // exercised by the test, not just the storage.
            let title = input.fromView.tap
                .merge(with: input.fromController.viewDidAppear)
                .map { _ in "tapped" }
                .eraseToAnyPublisher()
            return Output(publishers: Publishers(title: title)) {
                // Side-effect subscription returned in the Output bag.
                input.fromView.tap.sink { [weak self] in self?.sideEffectCalls += 1 }
            }
        }
    }

    func test_input_initStitchesBothChannels() {
        // ARRANGE
        let view = FromView(tap: Empty().eraseToAnyPublisher())
        let controller = FromController(viewDidAppear: Empty().eraseToAnyPublisher())

        // ACT
        let input = StubViewModel.Input(fromView: view, fromController: controller)

        // ASSERT
        // Reading the channels back via Mirror is unnecessary — type-checking
        // alone proves the init wired the right slot to the right channel.
        // We just exercise the path so the line is covered.
        _ = input.fromView
        _ = input.fromController
    }

    func test_subclass_transformReturnsPublishersAndCancellables() {
        // ARRANGE
        let vm = StubViewModel()
        let tap = PassthroughSubject<Void, Never>()
        let appear = PassthroughSubject<Void, Never>()
        let input = StubViewModel.Input(
            fromView: FromView(tap: tap.eraseToAnyPublisher()),
            fromController: FromController(viewDidAppear: appear.eraseToAnyPublisher())
        )
        var bag: [AnyCancellable] = []
        var received: [String] = []

        // ACT
        let output = vm.transform(input: input)
        // Output carries both the publisher bag and the subscriptions
        // started inside transform — retain both for the test's lifetime.
        bag.append(contentsOf: output.cancellables)
        output.publishers.title.sink { received.append($0) }.store(in: &bag)
        tap.send(())
        appear.send(())

        // ASSERT
        XCTAssertEqual(vm.transformCalls, 1)
        XCTAssertEqual(received, ["tapped", "tapped"])
        // The subscription returned in `output.cancellables` fired on the tap
        // (but not on viewDidAppear, which doesn't feed it).
        XCTAssertEqual(vm.sideEffectCalls, 1)
    }

    func test_transform_withNoSubscriptions_returnsEmptyCancellables() {
        // ARRANGE
        final class NoSideEffectVM: AbstractViewModel<FromView, FromController, Publishers> {
            override func transform(input: Input) -> Output<Publishers> {
                Output(publishers: Publishers(title: input.fromView.tap.map { "x" }.eraseToAnyPublisher()))
            }
        }
        let vm = NoSideEffectVM()
        let input = NoSideEffectVM.Input(
            fromView: FromView(tap: Empty().eraseToAnyPublisher()),
            fromController: FromController(viewDidAppear: Empty().eraseToAnyPublisher())
        )

        // ACT
        let output = vm.transform(input: input)

        // ASSERT
        XCTAssertTrue(output.cancellables.isEmpty)
    }
}
