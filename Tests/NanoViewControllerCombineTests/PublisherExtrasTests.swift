// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
@testable import NanoViewControllerCombine
import XCTest

/// Tests for `Publisher+Extras` operators (`replaceErrorWithEmpty`,
/// `mapToVoid`, `filterNil`, `orEmpty`, `flatMapLatest`, `withLatestFrom`,
/// `ifEmpty(switchTo:)`).
final class PublisherExtrasTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - replaceErrorWithEmpty

    func test_replaceErrorWithEmpty_swallowsError_completesWithoutValue() {
        // ARRANGE
        struct TestError: Error {}
        var received: [Int] = []
        var completed = false

        // ACT
        Fail<Int, TestError>(error: TestError())
            .replaceErrorWithEmpty()
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { received.append($0) }
            )
            .store(in: &cancellables)

        // ASSERT
        XCTAssertTrue(received.isEmpty)
        XCTAssertTrue(completed)
    }

    // MARK: - mapToVoid

    func test_mapToVoid_emitsVoidForEachUpstreamValue() {
        // ARRANGE
        var count = 0

        // ACT
        [1, 2, 3].publisher
            .mapToVoid()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in count += 1 })
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(count, 3)
    }

    // MARK: - filterNil

    func test_filterNil_dropsNilsAndUnwraps() {
        // ARRANGE
        var received: [Int] = []

        // ACT
        ([1, nil, 2, nil, 3] as [Int?]).publisher
            .filterNil()
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(received, [1, 2, 3])
    }

    // MARK: - orEmpty

    func test_orEmpty_publisher_replacesNilWithEmptyString() {
        // ARRANGE
        var received: [String] = []

        // ACT
        (["hi", nil, "bye"] as [String?]).publisher
            .orEmpty
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(received, ["hi", "", "bye"])
    }

    func test_orEmpty_anyPublisher_replacesNilWithEmptyString() {
        // ARRANGE
        var received: [String] = []
        let publisher: AnyPublisher<String?, Never> = (["hi", nil] as [String?]).publisher.eraseToAnyPublisher()

        // ACT
        publisher
            .orEmpty
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(received, ["hi", ""])
    }

    // MARK: - flatMapLatest

    func test_flatMapLatest_neverFailure_switchesToLatestInner() {
        // ARRANGE
        var received: [Int] = []
        let outer = PassthroughSubject<Int, Never>()
        outer
            .flatMapLatest { Just($0 * 10) }
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ACT
        outer.send(1)
        outer.send(2)

        // ASSERT
        XCTAssertEqual(received, [10, 20])
    }

    func test_flatMapLatest_genericFailure_switchesToLatestInner() {
        // ARRANGE
        struct TestError: Error {}
        var received: [Int] = []
        let outer = PassthroughSubject<Int, TestError>()
        outer
            .flatMapLatest { Just($0).setFailureType(to: TestError.self) }
            .sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
            .store(in: &cancellables)

        // ACT
        outer.send(7)
        outer.send(8)

        // ASSERT
        XCTAssertEqual(received, [7, 8])
    }

    // MARK: - withLatestFrom

    func test_withLatestFrom_emitsLatestOtherWhenUpstreamFires() {
        // ARRANGE
        let upstream = PassthroughSubject<Void, Never>()
        let other = CurrentValueSubject<Int, Never>(0)
        var received: [Int] = []
        upstream
            .withLatestFrom(other)
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ACT
        other.send(42)
        upstream.send(())
        other.send(99)
        upstream.send(())

        // ASSERT
        XCTAssertEqual(received, [42, 99])
    }

    func test_withLatestFrom_resultSelector_combinesValues() {
        // ARRANGE
        let upstream = PassthroughSubject<Int, Never>()
        let other = CurrentValueSubject<Int, Never>(10)
        var received: [Int] = []
        upstream
            .withLatestFrom(other) { up, oth in up + oth }
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ACT
        upstream.send(5)
        other.send(20)
        upstream.send(7)

        // ASSERT
        XCTAssertEqual(received, [15, 27])
    }

    func test_withLatestFrom_dropsValueWhenOtherHasNotEmitted() {
        // ARRANGE
        let upstream = PassthroughSubject<Void, Never>()
        let other = PassthroughSubject<Int, Never>()
        var received: [Int] = []
        upstream
            .withLatestFrom(other)
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ACT
        upstream.send(())

        // ASSERT
        XCTAssertTrue(received.isEmpty)

        // ACT
        other.send(1)
        upstream.send(())

        // ASSERT
        XCTAssertEqual(received, [1])
    }

    // MARK: - ifEmpty(switchTo:)

    func test_ifEmpty_emitsReplacementWhenUpstreamIsEmpty() {
        // ARRANGE
        var received: [Int] = []

        // ACT
        Empty<Int, Never>()
            .ifEmpty(switchTo: Just(99).eraseToAnyPublisher())
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(received, [99])
    }

    func test_ifEmpty_doesNotEmitReplacementWhenUpstreamHasValues() {
        // ARRANGE
        var received: [Int] = []

        // ACT
        Just(7)
            .ifEmpty(switchTo: Just(99).eraseToAnyPublisher())
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(received, [7])
    }
}
