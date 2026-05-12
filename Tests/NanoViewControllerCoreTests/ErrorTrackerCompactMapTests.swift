// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCore
import XCTest

/// Covers `ErrorTracker.compactMap(_:)` — the typed-error projection used by
/// sibling packages (e.g. a Validation module) to surface a typed slice of
/// captured errors without exposing the raw subject.
final class ErrorTrackerCompactMapTests: XCTestCase {
    private struct Validation: Swift.Error { let message: String }
    private struct Other: Swift.Error {}

    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func test_compactMap_projectsTypedErrors_dropsOthers() {
        let tracker = ErrorTracker()
        var messages: [String] = []

        tracker
            .compactMap { ($0 as? Validation)?.message }
            .sink { messages.append($0) }
            .store(in: &cancellables)

        Fail<Void, Validation>(error: Validation(message: "oops"))
            .trackError(tracker)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        Fail<Void, Other>(error: Other())
            .trackError(tracker)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        XCTAssertEqual(messages, ["oops"])
    }
}
