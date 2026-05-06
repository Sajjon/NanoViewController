// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import UIKit

/// Abstracts the system pasteboard so view-models can copy user-visible text
/// without touching `UIPasteboard.general` directly.
///
/// Unit tests register a `MockPasteboard` that records values instead of
/// mutating the real pasteboard. The abstraction also makes it natural to
/// declare *expiration* semantics for sensitive copies (keystore JSON, mnemonic
/// phrases, private keys), where the legacy `UIPasteboard.general.string = …`
/// API would leave the value sitting around indefinitely.
///
/// ## Example — copying a transaction id versus a mnemonic
///
/// ```swift
/// import NanoViewControllerDIPrimitives
///
/// final class TransactionViewModel {
///     private let pasteboard: any Pasteboard
///     init(pasteboard: any Pasteboard) { self.pasteboard = pasteboard }
///
///     /// Public, low-sensitivity — no expiration.
///     func copyTransactionID(_ id: String) {
///         pasteboard.copy(id)         // convenience overload, expiringAfter = nil
///     }
///
///     /// Sensitive — auto-clear after 30 seconds so the value doesn't sit on
///     /// the pasteboard / sync via Universal Clipboard / get scraped by a
///     /// clipboard-manager app.
///     func copyMnemonic(_ phrase: String) {
///         pasteboard.copy(phrase, expiringAfter: 30)
///     }
/// }
///
/// // Test:
/// final class MockPasteboard: Pasteboard {
///     private(set) var copies: [(String, TimeInterval?)] = []
///     func copy(_ string: String, expiringAfter: TimeInterval?) {
///         copies.append((string, expiringAfter))
///     }
/// }
///
/// let mock = MockPasteboard()
/// let vm = TransactionViewModel(pasteboard: mock)
/// vm.copyMnemonic("alpha bravo charlie …")
/// XCTAssertEqual(mock.copies.count, 1)
/// XCTAssertEqual(mock.copies[0].1, 30)        // expiration recorded
/// ```
@MainActor
public protocol Pasteboard: AnyObject {
    /// Copy `string` to the system pasteboard.
    ///
    /// - Parameters:
    ///   - string: The value to write.
    ///   - expiringAfter: Optional auto-clear interval (seconds). Use this for
    ///     anything sensitive (keystore JSON, private keys, mnemonics) so the
    ///     value doesn't sit on the system pasteboard indefinitely — it would
    ///     otherwise sync to Universal Clipboard, be picked up by clipboard
    ///     managers, etc. `nil` (default) keeps the legacy "no expiration"
    ///     behaviour for non-sensitive copies (receive address, transaction id).
    func copy(_ string: String, expiringAfter: TimeInterval?)
}

public extension Pasteboard {
    /// Convenience for non-sensitive copies — no expiration.
    ///
    /// - Parameter string: Value to write to `UIPasteboard.general`.
    func copy(_ string: String) {
        copy(string, expiringAfter: nil)
    }
}

/// Production implementation that writes through to `UIPasteboard.general`.
@MainActor
public final class DefaultPasteboard: Pasteboard {
    /// Trivial init — no dependencies.
    public init() {}

    /// Writes `string` to `UIPasteboard.general`.
    ///
    /// With `expiringAfter` set, uses `setItems(_:options:)` with
    /// `.expirationDate` so the system auto-clears the entry — the pasteboard
    /// doesn't auto-sync to Universal Clipboard once expired, and clipboard
    /// managers see only the cleared state after the deadline.
    ///
    /// - Parameters:
    ///   - string: Value to write.
    ///   - expiringAfter: Optional auto-clear interval (seconds). `nil` for no expiration.
    public func copy(_ string: String, expiringAfter: TimeInterval?) {
        guard let expiringAfter else {
            UIPasteboard.general.string = string
            return
        }
        let expirationDate = Date().addingTimeInterval(expiringAfter)
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: string]],
            options: [.expirationDate: expirationDate]
        )
    }
}
