// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerController
@testable import NanoViewControllerCore
import XCTest

/// Tests for `AbstractViewModel` — the generic base class every concrete
/// scene-bound ViewModel inherits from. Covers the synthesised `Input` struct,
/// and verifies that subclassing + overriding `transform` produces an
/// ``Output`` carrying the publisher bag, the navigation publisher, and the
/// subscriptions started inside `transform`.
///
/// `AbstractViewModel` uses the standard ``InputFromController`` channel;
/// these tests construct a stub filled with `Empty()` publishers and
/// `PassthroughSubject`s where the wiring matters.
@MainActor
final class AbstractViewModelTests: XCTestCase {
    private struct FromView { let tap: AnyPublisher<Void, Never> }
    private struct Publishers { let title: AnyPublisher<String, Never> }

    /// Builds an `InputFromController` whose lifecycle publishers come from
    /// the supplied subjects (or `Empty()` by default). The write-back
    /// subjects are real `PassthroughSubject`s the test can drive.
    private static func makeStubInputFromController(
        viewDidAppear: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher()
    ) -> InputFromController {
        InputFromController(
            viewDidLoad: Empty().eraseToAnyPublisher(),
            viewWillAppear: Empty().eraseToAnyPublisher(),
            viewDidAppear: viewDidAppear,
            leftBarButtonTrigger: Empty().eraseToAnyPublisher(),
            rightBarButtonTrigger: Empty().eraseToAnyPublisher(),
            titleSubject: .init(),
            leftBarButtonContentSubject: .init(),
            rightBarButtonContentSubject: .init(),
            toastSubject: .init()
        )
    }

    private final class StubViewModel: AbstractViewModel<FromView, Publishers, Never> {
        private(set) var transformCalls = 0
        // Mutating side-effect counter that proves the subscription block ran.
        private(set) var sideEffectCalls = 0
        override func transform(input: Input) -> Output<Publishers, Never> {
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

    func test_subclass_transformReturnsPublishersAndCancellables() {
        // ARRANGE
        let vm = StubViewModel()
        let tap = PassthroughSubject<Void, Never>()
        let appear = PassthroughSubject<Void, Never>()
        let input = StubViewModel.Input(
            fromView: FromView(tap: tap.eraseToAnyPublisher()),
            fromController: Self.makeStubInputFromController(
                viewDidAppear: appear.eraseToAnyPublisher()
            )
        )
        var bag: [AnyCancellable] = []
        var received: [String] = []

        // ACT
        let output = vm.transform(input: input)
        // Output carries the publisher bag, the navigation publisher, and the
        // subscriptions started inside transform — retain everything for the
        // test's lifetime.
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
        final class NoSideEffectVM: AbstractViewModel<FromView, Publishers, Never> {
            override func transform(input: Input) -> Output<Publishers, Never> {
                Output(publishers: Publishers(title: input.fromView.tap.map { "x" }.eraseToAnyPublisher()))
            }
        }
        let vm = NoSideEffectVM()
        let input = NoSideEffectVM.Input(
            fromView: FromView(tap: Empty().eraseToAnyPublisher()),
            fromController: Self.makeStubInputFromController()
        )

        // ACT
        let output = vm.transform(input: input)

        // ASSERT
        XCTAssertTrue(output.cancellables.isEmpty)
    }

    func test_transform_withNavigation_emitsThroughOutputChannel() {
        // ARRANGE
        enum Step: Sendable, Equatable { case finished }
        final class NavigatingVM: AbstractViewModel<FromView, Publishers, Step> {
            override func transform(input: Input) -> Output<Publishers, Step> {
                let nav = PassthroughSubject<Step, Never>()
                return Output(
                    publishers: Publishers(title: Empty().eraseToAnyPublisher()),
                    navigation: nav.eraseToAnyPublisher()
                ) {
                    input.fromView.tap.sink { nav.send(.finished) }
                }
            }
        }
        let vm = NavigatingVM()
        let tap = PassthroughSubject<Void, Never>()
        let input = NavigatingVM.Input(
            fromView: FromView(tap: tap.eraseToAnyPublisher()),
            fromController: Self.makeStubInputFromController()
        )
        var bag: [AnyCancellable] = []
        var steps: [Step] = []

        // ACT
        let output = vm.transform(input: input)
        bag.append(contentsOf: output.cancellables)
        output.navigation.sink { steps.append($0) }.store(in: &bag)
        tap.send(())

        // ASSERT
        XCTAssertEqual(steps, [.finished])
    }
}
