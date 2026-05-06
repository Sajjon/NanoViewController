// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Foundation

/// Abstracts reading "what time is it now" so callers can be tested without
/// depending on the real wall clock.
///
/// Production uses ``DefaultDateProvider`` (returns `Date()`). Tests register
/// a fixed-clock double, which returns a deterministic instant so
/// relative-time formatting and "balance last updated" timestamps stay
/// reproducible.
///
/// ## Example — relative-time label
///
/// ```swift
/// import NanoViewControllerDIPrimitives
///
/// final class BalanceViewModel {
///     private let dateProvider: any DateProvider
///     private let lastFetched = CurrentValueSubject<Date?, Never>(nil)
///
///     init(dateProvider: any DateProvider) { self.dateProvider = dateProvider }
///
///     var lastUpdatedText: AnyPublisher<String, Never> {
///         lastFetched.compactMap { $0 }
///             .map { [dateProvider] fetched -> String in
///                 let now = dateProvider.now()
///                 let seconds = Int(now.timeIntervalSince(fetched))
///                 return "Updated \(seconds)s ago"
///             }
///             .eraseToAnyPublisher()
///     }
///
///     func refresh() async throws {
///         let balance = try await api.fetchBalance()
///         lastFetched.send(dateProvider.now())
///         // …
///     }
/// }
///
/// // Test:
/// final class FixedDateProvider: DateProvider {
///     var fixed: Date
///     init(_ date: Date) { fixed = date }
///     func now() -> Date { fixed }
/// }
///
/// let provider = FixedDateProvider(Date(timeIntervalSince1970: 1_700_000_000))
/// let vm = BalanceViewModel(dateProvider: provider)
/// // Drive `lastFetched` and assert the formatted text — fully deterministic.
/// ```
public protocol DateProvider: AnyObject {
    /// The current instant according to whichever implementation is registered.
    func now() -> Date
}

/// Production ``DateProvider`` backed by `Date()`.
public final class DefaultDateProvider: DateProvider {
    /// Trivial init — no dependencies.
    public init() {}

    /// Returns `Date()`. Pure pass-through to the system wall clock.
    public func now() -> Date {
        Date()
    }
}
