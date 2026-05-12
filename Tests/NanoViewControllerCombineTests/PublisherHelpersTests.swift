// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCombine
import XCTest

// swiftlint:disable type_body_length

/// Covers Publisher+Helpers static constructors and combineLatest overloads.
final class PublisherHelpersTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - static constructors

    func test_just_emitsSingleValueThenCompletes() {
        // ARRANGE
        var received: [Int] = []
        var completed = false

        // ACT
        AnyPublisher<Int, Never>.just(42)
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { received.append($0) }
            )
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(received, [42])
        XCTAssertTrue(completed)
    }

    func test_empty_completesWithoutEmittingAnyValue() {
        // ARRANGE
        var received: [Int] = []
        var completed = false

        // ACT
        AnyPublisher<Int, Never>.empty()
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { received.append($0) }
            )
            .store(in: &cancellables)

        // ASSERT
        XCTAssertTrue(received.isEmpty)
        XCTAssertTrue(completed)
    }

    func test_never_neverEmitsAndNeverCompletes() {
        // ARRANGE
        var received: [Int] = []
        var completed = false

        // ACT
        AnyPublisher<Int, Never>.never()
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { received.append($0) }
            )
            .store(in: &cancellables)

        // ASSERT
        XCTAssertTrue(received.isEmpty)
        XCTAssertFalse(completed)
    }

    // MARK: - merge

    func test_mergeVariadic_combinesAllPublishers() {
        // ARRANGE
        var received: [Int] = []

        // ACT
        AnyPublisher<Int, Never>.merge(
            AnyPublisher<Int, Never>.just(1),
            AnyPublisher<Int, Never>.just(2),
            AnyPublisher<Int, Never>.just(3)
        )
        .sink { received.append($0) }
        .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(Set(received), Set([1, 2, 3]))
    }

    func test_mergeArray_combinesAllPublishers() {
        // ARRANGE
        var received: [Int] = []

        // ACT
        AnyPublisher<Int, Never>.merge(
            [AnyPublisher<Int, Never>.just(10), AnyPublisher<Int, Never>.just(20)]
        )
        .sink { received.append($0) }
        .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(Set(received), Set([10, 20]))
    }

    func test_mergeTwo_combinesTwoPublishers() {
        // ARRANGE
        var received: [Int] = []

        // ACT
        AnyPublisher<Int, Never>.merge(
            Just(1),
            Just(2)
        )
        .sink { received.append($0) }
        .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(Set(received), Set([1, 2]))
    }

    func test_mergeThree_combinesThreePublishers() {
        // ARRANGE
        var received: [Int] = []

        // ACT
        AnyPublisher<Int, Never>.merge(
            Just(1),
            Just(2),
            Just(3)
        )
        .sink { received.append($0) }
        .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(Set(received), Set([1, 2, 3]))
    }

    func test_mergeFour_combinesFourPublishers() {
        // ARRANGE
        var received: [Int] = []

        // ACT
        AnyPublisher<Int, Never>.merge(
            Just(1),
            Just(2),
            Just(3),
            Just(4)
        )
        .sink { received.append($0) }
        .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(Set(received), Set([1, 2, 3, 4]))
    }

    // MARK: - free-function combineLatest

    func test_combineLatest_twoPublishers_emitsLatestTuple() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<String, Never>("x")
        var received: [(Int, String)] = []
        combineLatest(a, b)
            .sink { received.append($0) }
            .store(in: &cancellables)

        // ACT
        a.send(2)
        b.send("y")

        // ASSERT
        XCTAssertEqual(received.last?.0, 2)
        XCTAssertEqual(received.last?.1, "y")
    }

    // swiftlint:disable large_tuple
    func test_combineLatest_threePublishers_emitsLatestTriple() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        var last: (Int, Int, Int)?

        // ACT
        combineLatest(a, b, c)
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last?.0, 1)
        XCTAssertEqual(last?.1, 2)
        XCTAssertEqual(last?.2, 3)
    }

    func test_combineLatest_fourPublishers_emitsLatestQuadruple() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        let d = CurrentValueSubject<Int, Never>(4)
        var last: (Int, Int, Int, Int)?

        // ACT
        combineLatest(a, b, c, d)
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last?.0, 1)
        XCTAssertEqual(last?.3, 4)
    }

    // swiftlint:enable large_tuple

    func test_combineLatest_twoPublishersWithSelector_mapsResult() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(3)
        let b = CurrentValueSubject<Int, Never>(4)
        var last: Int?

        // ACT
        combineLatest(a, b, resultSelector: +)
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last, 7)
    }

    func test_combineLatest_threePublishersWithSelector_mapsResult() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        var last: Int?

        // ACT
        combineLatest(a, b, c) { $0 + $1 + $2 }
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last, 6)
    }

    func test_combineLatest_fourPublishersWithSelector_mapsResult() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        let d = CurrentValueSubject<Int, Never>(4)
        var last: Int?

        // ACT
        combineLatest(a, b, c, d) { $0 + $1 + $2 + $3 }
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last, 10)
    }

    func test_combineLatest_fivePublishersWithSelector_mapsResult() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        let d = CurrentValueSubject<Int, Never>(4)
        let e = CurrentValueSubject<Int, Never>(5)
        var last: Int?

        // ACT
        combineLatest(a, b, c, d, e) { $0 + $1 + $2 + $3 + $4 }
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last, 15)
    }

    // MARK: - AnyPublisher.combineLatest static overloads

    func test_anyPublisher_combineLatest_twoPublishers_emitsLatestTuple() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<String, Never>("a")
        var last: (Int, String)?

        // ACT
        AnyPublisher<(Int, String), Never>.combineLatest(a, b)
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last?.0, 1)
        XCTAssertEqual(last?.1, "a")
    }

    // swiftlint:disable large_tuple
    func test_anyPublisher_combineLatest_threePublishers_emitsLatestTriple() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        var last: (Int, Int, Int)?

        // ACT
        AnyPublisher<(Int, Int, Int), Never>.combineLatest(a, b, c)
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last?.2, 3)
    }

    func test_anyPublisher_combineLatest_fourPublishers_emitsLatestQuadruple() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        let d = CurrentValueSubject<Int, Never>(4)
        var last: (Int, Int, Int, Int)?

        // ACT
        AnyPublisher<(Int, Int, Int, Int), Never>.combineLatest(a, b, c, d)
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last?.3, 4)
    }

    // swiftlint:enable large_tuple

    func test_anyPublisher_combineLatest_twoPublishersWithSelector_mapsResult() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(3)
        let b = CurrentValueSubject<Int, Never>(4)
        var last: Int?

        // ACT
        AnyPublisher<Int, Never>.combineLatest(a, b, resultSelector: +)
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last, 7)
    }

    func test_anyPublisher_combineLatest_threePublishersWithSelector_mapsResult() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        var last: Int?

        // ACT
        AnyPublisher<Int, Never>.combineLatest(a, b, c) { $0 + $1 + $2 }
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last, 6)
    }

    func test_anyPublisher_combineLatest_fourPublishersWithSelector_mapsResult() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        let d = CurrentValueSubject<Int, Never>(4)
        var last: Int?

        // ACT
        AnyPublisher<Int, Never>.combineLatest(a, b, c, d) { $0 + $1 + $2 + $3 }
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last, 10)
    }

    func test_anyPublisher_combineLatest_fivePublishersWithSelector_mapsResult() {
        // ARRANGE
        let a = CurrentValueSubject<Int, Never>(1)
        let b = CurrentValueSubject<Int, Never>(2)
        let c = CurrentValueSubject<Int, Never>(3)
        let d = CurrentValueSubject<Int, Never>(4)
        let e = CurrentValueSubject<Int, Never>(5)
        var last: Int?

        // ACT
        AnyPublisher<Int, Never>.combineLatest(a, b, c, d, e) { $0 + $1 + $2 + $3 + $4 }
            .sink { last = $0 }
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(last, 15)
    }
}

// swiftlint:enable type_body_length
