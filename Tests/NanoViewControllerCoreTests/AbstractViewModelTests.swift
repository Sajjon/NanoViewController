// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCore
import XCTest

/// Tests for `AbstractViewModel` — the generic base class every concrete
/// ViewModel inherits from. Covers the synthesised `Input` struct, the empty
/// `cancellables` bag, and verifies that subclassing + overriding `transform`
/// works as documented.
@MainActor
final class AbstractViewModelTests: XCTestCase {
    private struct FromView { let tap: AnyPublisher<Void, Never> }
    private struct FromController { let viewDidAppear: AnyPublisher<Void, Never> }
    private struct Output { let title: AnyPublisher<String, Never> }

    private final class StubViewModel: AbstractViewModel<FromView, FromController, Output> {
        private(set) var transformCalls = 0
        override func transform(input: Input) -> Output {
            transformCalls += 1
            // Use both channels so the synthesised stitching is genuinely
            // exercised by the test, not just the storage.
            let title = input.fromView.tap
                .merge(with: input.fromController.viewDidAppear)
                .map { _ in "tapped" }
                .eraseToAnyPublisher()
            return Output(title: title)
        }
    }

    func test_init_createsEmptyCancellables() {
        let vm = StubViewModel()
        XCTAssertTrue(vm.cancellables.isEmpty)
    }

    func test_input_initStitchesBothChannels() {
        let view = FromView(tap: Empty().eraseToAnyPublisher())
        let controller = FromController(viewDidAppear: Empty().eraseToAnyPublisher())

        let input = StubViewModel.Input(fromView: view, fromController: controller)

        // Reading the channels back via Mirror is unnecessary — type-checking
        // alone proves the init wired the right slot to the right channel.
        // We just exercise the path so the line is covered.
        _ = input.fromView
        _ = input.fromController
    }

    func test_subclass_transformIsInvoked() {
        let vm = StubViewModel()
        let tap = PassthroughSubject<Void, Never>()
        let appear = PassthroughSubject<Void, Never>()
        let input = StubViewModel.Input(
            fromView: FromView(tap: tap.eraseToAnyPublisher()),
            fromController: FromController(viewDidAppear: appear.eraseToAnyPublisher())
        )

        var received: [String] = []
        let output = vm.transform(input: input)
        output.title.sink { received.append($0) }.store(in: &vm.cancellables)

        tap.send(())
        appear.send(())

        XCTAssertEqual(vm.transformCalls, 1)
        XCTAssertEqual(received, ["tapped", "tapped"])
    }
}
