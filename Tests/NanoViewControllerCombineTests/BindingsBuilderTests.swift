// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCombine
import XCTest

/// Tests for `@BindingsBuilder` — the result builder that lets
/// `populate(with:)` be written as a sequence of binding statements rather
/// than an explicit `[AnyCancellable]` array literal.
///
/// The builder collapses every `buildExpression`/`buildBlock`/`buildOptional`/
/// `buildEither`/`buildArray` overload into a single flat `[AnyCancellable]`
/// — these tests exercise each of those control-flow paths.
@MainActor
final class BindingsBuilderTests: XCTestCase {
    // MARK: - buildExpression(AnyCancellable) + buildBlock

    func test_singleExpression_lifts_to_singletonArray() {
        // ARRANGE
        let cancellable = AnyCancellable {}

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            cancellable
        }

        // ASSERT
        XCTAssertEqual(result.count, 1)
    }

    func test_multipleStatements_combine_in_sourceOrder() {
        // ARRANGE
        let a = AnyCancellable {}
        let b = AnyCancellable {}
        let c = AnyCancellable {}

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            a
            b
            c
        }

        // ASSERT
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result[0] === a)
        XCTAssertTrue(result[1] === b)
        XCTAssertTrue(result[2] === c)
    }

    // MARK: - buildExpression([AnyCancellable]) — array splice

    func test_arrayLiteralStatement_keeps_workingForLegacyCallers() {
        // ARRANGE
        let a = AnyCancellable {}
        let b = AnyCancellable {}

        // ACT
        // The legacy `populate(with:) { [a, b] }` shape — a single array
        // expression — must keep working under the builder.
        let result: [AnyCancellable] = BindingsBuilder.build {
            [a, b]
        }

        // ASSERT
        XCTAssertEqual(result.count, 2)
    }

    func test_mixedArrayAndSingletonStatements_flatten_inOrder() {
        // ARRANGE
        let a = AnyCancellable {}
        let b = AnyCancellable {}
        let c = AnyCancellable {}

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            a
            [b, c]
        }

        // ASSERT
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result[0] === a)
        XCTAssertTrue(result[1] === b)
        XCTAssertTrue(result[2] === c)
    }

    // MARK: - buildOptional (if without else)

    func test_ifTrue_includes_branch() {
        // ARRANGE
        let a = AnyCancellable {}
        let b = AnyCancellable {}
        let condition = true

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            a
            if condition {
                b
            }
        }

        // ASSERT
        XCTAssertEqual(result.count, 2)
    }

    func test_ifFalse_omits_branch() {
        // ARRANGE
        let a = AnyCancellable {}
        let b = AnyCancellable {}
        let condition = false

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            a
            if condition {
                b
            }
        }

        // ASSERT
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] === a)
    }

    // MARK: - buildEither (if/else)

    func test_ifElse_takesFirstBranch_whenConditionTrue() {
        // ARRANGE
        let trueCancellable = AnyCancellable {}
        let falseCancellable = AnyCancellable {}
        let condition = true

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            if condition {
                trueCancellable
            } else {
                falseCancellable
            }
        }

        // ASSERT
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] === trueCancellable)
    }

    func test_ifElse_takesSecondBranch_whenConditionFalse() {
        // ARRANGE
        let trueCancellable = AnyCancellable {}
        let falseCancellable = AnyCancellable {}
        let condition = false

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            if condition {
                trueCancellable
            } else {
                falseCancellable
            }
        }

        // ASSERT
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0] === falseCancellable)
    }

    // MARK: - buildArray (for-loops)

    func test_forLoop_emitsOnePerIteration() {
        // ARRANGE
        let cancellables = (0 ..< 5).map { _ in AnyCancellable {} }

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            for cancellable in cancellables {
                cancellable
            }
        }

        // ASSERT
        XCTAssertEqual(result.count, 5)
    }

    func test_forLoop_overEmptyCollection_emitsNothing() {
        // ARRANGE
        let cancellables: [AnyCancellable] = []

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            for cancellable in cancellables {
                cancellable
            }
        }

        // ASSERT
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - buildLimitedAvailability

    func test_availabilityCheck_passesThrough() {
        // ARRANGE
        let cancellable = AnyCancellable {}

        // ACT
        let result: [AnyCancellable] = BindingsBuilder.build {
            if #available(iOS 17, *) {
                cancellable
            }
        }

        // ASSERT
        XCTAssertEqual(result.count, 1)
    }
}

// MARK: - Test helper

private extension BindingsBuilder {
    /// Trampolines into the result builder with a builder-typed parameter so
    /// the tests can write `BindingsBuilder.build { … }` instead of
    /// constructing a function with the attribute. Not intended for production.
    @MainActor
    static func build(@BindingsBuilder _ build: () -> [AnyCancellable]) -> [AnyCancellable] {
        build()
    }
}
