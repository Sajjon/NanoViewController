// MIT License — Copyright (c) 2018-2026 Open Zesame

import UIKit

/// Abstracts `UIApplication.shared.open(_:)` so tests can register a no-op
/// implementation.
///
/// In the iOS simulator the real call can dispatch a workspace round-trip
/// that never completes within a unit-test timeout, so depending on it
/// directly tends to make CI flake. The abstraction also lets unit tests
/// assert that a "tap to open in Safari" really did request the right URL.
///
/// ## Example — open a "view on block explorer" URL
///
/// ```swift
/// import NanoViewControllerDIPrimitives
///
/// final class TransactionViewModel {
///     private let urlOpener: any UrlOpener
///     init(urlOpener: any UrlOpener) { self.urlOpener = urlOpener }
///
///     func viewOnExplorer(txid: String) {
///         let url = URL(string: "https://etherscan.io/tx/\(txid)")!
///         urlOpener.open(url)
///     }
/// }
///
/// // Test:
/// final class RecordingUrlOpener: UrlOpener {
///     private(set) var opened: [URL] = []
///     func open(_ url: URL) { opened.append(url) }
/// }
///
/// let opener = RecordingUrlOpener()
/// let vm = TransactionViewModel(urlOpener: opener)
/// vm.viewOnExplorer(txid: "0xabc…")
/// XCTAssertEqual(opener.opened.first?.absoluteString,
///                "https://etherscan.io/tx/0xabc…")
/// ```
public protocol UrlOpener: AnyObject {
    /// Hands `url` off to the system to open in the registered handler app.
    ///
    /// - Parameter url: The URL to launch.
    func open(_ url: URL)
}

/// Production implementation that forwards to `UIApplication.shared.open`.
public final class DefaultUrlOpener: UrlOpener {
    /// Trivial init — no dependencies.
    public init() {}

    /// Opens `url` via the system app-launch flow. No options, no callback.
    public func open(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
