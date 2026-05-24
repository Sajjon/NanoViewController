// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
import Foundation

// Sugar that mirrors RxSwift's free-function-style `Observable.combineLatest(_:_:)`
// and turns Combine's verbose static factories into one-liners.
//
// ## Example — RxSwift-style combineLatest at the top level
//
// ```swift
// import Combine
// import NanoViewControllerCombine
//
// let formIsValid = combineLatest(usernamePublisher, passwordPublisher) {
//     !$0.isEmpty && $1.count >= 8
// }
//
// // and for trivial constructors:
// let initial: AnyPublisher<Int, Never> = .just(0)
// let nothing: AnyPublisher<String, Never> = .empty()
// let merged = AnyPublisher.merge(p1, p2, p3)
// ```

// MARK: - AnyPublisher static constructors

public extension AnyPublisher where Failure == Never {
    /// Convenience over `Just(value).eraseToAnyPublisher()`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let zero: AnyPublisher<Int, Never> = .just(0)
    /// ```
    static func just(_ value: Output) -> AnyPublisher<Output, Never> {
        Just(value).eraseToAnyPublisher()
    }

    /// A publisher that completes immediately with no values.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // No initial errors to surface yet.
    /// let initialErrors: AnyPublisher<String, Never> = .empty()
    /// ```
    static func empty() -> AnyPublisher<Output, Never> {
        Empty<Output, Never>().eraseToAnyPublisher()
    }

    /// A publisher that never emits and never completes.
    ///
    /// Useful as a "no-op" upstream when you need to satisfy a generic
    /// signature without producing values.
    static func never() -> AnyPublisher<Output, Never> {
        Empty<Output, Never>(completeImmediately: false).eraseToAnyPublisher()
    }

    /// Variadic merge.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let allTaps = AnyPublisher.merge(button1.tapPublisher,
    ///                                  button2.tapPublisher,
    ///                                  button3.tapPublisher)
    /// ```
    static func merge(_ publishers: AnyPublisher<Output, Never>...) -> AnyPublisher<Output, Never> {
        Publishers.MergeMany(publishers).eraseToAnyPublisher()
    }

    /// Array overload of ``merge(_:)-...``.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let allButtonTaps = AnyPublisher.merge(buttons.map(\.tapPublisher))
    /// ```
    static func merge(_ publishers: [AnyPublisher<Output, Never>]) -> AnyPublisher<Output, Never> {
        Publishers.MergeMany(publishers).eraseToAnyPublisher()
    }

    /// 2-publisher merge.
    static func merge(
        _ p1: some Publisher<Output, Never>,
        _ p2: some Publisher<Output, Never>
    ) -> AnyPublisher<Output, Never> {
        p1.merge(with: p2).eraseToAnyPublisher()
    }

    /// 3-publisher merge.
    static func merge(
        _ p1: some Publisher<Output, Never>,
        _ p2: some Publisher<Output, Never>,
        _ p3: some Publisher<Output, Never>
    ) -> AnyPublisher<Output, Never> {
        Publishers.Merge3(p1, p2, p3).eraseToAnyPublisher()
    }

    /// 4-publisher merge.
    static func merge(
        _ p1: some Publisher<Output, Never>,
        _ p2: some Publisher<Output, Never>,
        _ p3: some Publisher<Output, Never>,
        _ p4: some Publisher<Output, Never>
    ) -> AnyPublisher<Output, Never> {
        Publishers.Merge4(p1, p2, p3, p4).eraseToAnyPublisher()
    }
}

// MARK: - combineLatest free functions

/// 2-arity free-function `combineLatest`.
///
/// Mirrors RxSwift's static `Observable.combineLatest(a, b)` so callsites can
/// read more naturally than `a.combineLatest(b)` when both publishers are
/// "first-class" inputs at the same level.
///
/// ## Example
///
/// ```swift
/// let isValid = combineLatest(username, password)
///     .map { !$0.isEmpty && $1.count >= 8 }
/// ```
public func combineLatest<A, B>(
    _ a: some Publisher<A, Never>,
    _ b: some Publisher<B, Never>
) -> AnyPublisher<(A, B), Never> {
    a.combineLatest(b).eraseToAnyPublisher()
}

// swiftlint:disable large_tuple
/// 3-arity free-function `combineLatest`.
public func combineLatest<A, B, C>(
    _ a: some Publisher<A, Never>,
    _ b: some Publisher<B, Never>,
    _ c: some Publisher<C, Never>
) -> AnyPublisher<(A, B, C), Never> {
    a.combineLatest(b, c).eraseToAnyPublisher()
}

/// 4-arity free-function `combineLatest`.
public func combineLatest<A, B, C, D>(
    _ a: some Publisher<A, Never>,
    _ b: some Publisher<B, Never>,
    _ c: some Publisher<C, Never>,
    _ d: some Publisher<D, Never>
) -> AnyPublisher<(A, B, C, D), Never> {
    a.combineLatest(b, c, d).eraseToAnyPublisher()
}

// swiftlint:enable large_tuple

/// 2-arity `combineLatest` with a result-selector closure.
///
/// ## Example
///
/// ```swift
/// let summary = combineLatest(items, currency) { items, currency in
///     items.reduce(0) { $0 + $1.amount } * currency.rate
/// }
/// ```
public func combineLatest<A, B, R>(
    _ a: some Publisher<A, Never>,
    _ b: some Publisher<B, Never>,
    resultSelector: @escaping (A, B) -> R
) -> AnyPublisher<R, Never> {
    a.combineLatest(b, resultSelector).eraseToAnyPublisher()
}

/// 3-arity `combineLatest` with a result-selector closure.
public func combineLatest<A, B, C, R>(
    _ a: some Publisher<A, Never>,
    _ b: some Publisher<B, Never>,
    _ c: some Publisher<C, Never>,
    resultSelector: @escaping (A, B, C) -> R
) -> AnyPublisher<R, Never> {
    a.combineLatest(b, c, resultSelector).eraseToAnyPublisher()
}

// swiftlint:disable function_parameter_count
/// 4-arity `combineLatest` with a result-selector closure.
public func combineLatest<A, B, C, D, R>(
    _ a: some Publisher<A, Never>,
    _ b: some Publisher<B, Never>,
    _ c: some Publisher<C, Never>,
    _ d: some Publisher<D, Never>,
    resultSelector: @escaping (A, B, C, D) -> R
) -> AnyPublisher<R, Never> {
    Publishers.CombineLatest4(a, b, c, d)
        .map { resultSelector($0.0, $0.1, $0.2, $0.3) }
        .eraseToAnyPublisher()
}

/// 5-arity `combineLatest` with a result-selector closure.
///
/// Combine ships `CombineLatest{2,3,4}` only — for 5 inputs we nest
/// `CombineLatest4` and the trailing `e` via `combineLatest`.
public func combineLatest<A, B, C, D, E, R>(
    _ a: some Publisher<A, Never>,
    _ b: some Publisher<B, Never>,
    _ c: some Publisher<C, Never>,
    _ d: some Publisher<D, Never>,
    _ e: some Publisher<E, Never>,
    resultSelector: @escaping (A, B, C, D, E) -> R
) -> AnyPublisher<R, Never> {
    Publishers.CombineLatest4(a, b, c, d)
        .combineLatest(e)
        .map { tuple4, eVal in resultSelector(tuple4.0, tuple4.1, tuple4.2, tuple4.3, eVal) }
        .eraseToAnyPublisher()
}

// swiftlint:enable function_parameter_count

// MARK: - AnyPublisher.combineLatest(...) static overloads

public extension AnyPublisher where Failure == Never {
    /// Static-method form of the 2-arity `combineLatest`. Same semantics as
    /// the free function; some call sites prefer this style.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let isValid = AnyPublisher.combineLatest(username, password)
    ///     .map { !$0.isEmpty && $1.count >= 8 }
    ///     .eraseToAnyPublisher()
    /// ```
    static func combineLatest<A, B>(
        _ a: some Publisher<A, Never>,
        _ b: some Publisher<B, Never>
    ) -> AnyPublisher<(A, B), Never> {
        a.combineLatest(b).eraseToAnyPublisher()
    }

    // swiftlint:disable large_tuple
    /// 3-arity static `combineLatest`.
    static func combineLatest<A, B, C>(
        _ a: some Publisher<A, Never>,
        _ b: some Publisher<B, Never>,
        _ c: some Publisher<C, Never>
    ) -> AnyPublisher<(A, B, C), Never> {
        a.combineLatest(b, c).eraseToAnyPublisher()
    }

    /// 4-arity static `combineLatest`.
    static func combineLatest<A, B, C, D>(
        _ a: some Publisher<A, Never>,
        _ b: some Publisher<B, Never>,
        _ c: some Publisher<C, Never>,
        _ d: some Publisher<D, Never>
    ) -> AnyPublisher<(A, B, C, D), Never> {
        a.combineLatest(b, c, d).eraseToAnyPublisher()
    }

    // swiftlint:enable large_tuple

    /// 2-arity static `combineLatest` with a result-selector closure.
    static func combineLatest<A, B, R>(
        _ a: some Publisher<A, Never>,
        _ b: some Publisher<B, Never>,
        resultSelector: @escaping (A, B) -> R
    ) -> AnyPublisher<R, Never> {
        a.combineLatest(b, resultSelector).eraseToAnyPublisher()
    }

    /// 3-arity static `combineLatest` with a result-selector closure.
    static func combineLatest<A, B, C, R>(
        _ a: some Publisher<A, Never>,
        _ b: some Publisher<B, Never>,
        _ c: some Publisher<C, Never>,
        resultSelector: @escaping (A, B, C) -> R
    ) -> AnyPublisher<R, Never> {
        a.combineLatest(b, c, resultSelector).eraseToAnyPublisher()
    }

    // swiftlint:disable function_parameter_count
    /// 4-arity static `combineLatest` with a result-selector closure.
    static func combineLatest<A, B, C, D, R>(
        _ a: some Publisher<A, Never>,
        _ b: some Publisher<B, Never>,
        _ c: some Publisher<C, Never>,
        _ d: some Publisher<D, Never>,
        resultSelector: @escaping (A, B, C, D) -> R
    ) -> AnyPublisher<R, Never> {
        Publishers.CombineLatest4(a, b, c, d)
            .map { resultSelector($0.0, $0.1, $0.2, $0.3) }
            .eraseToAnyPublisher()
    }

    /// 5-arity static `combineLatest` with a result-selector closure.
    static func combineLatest<A, B, C, D, E, R>(
        _ a: some Publisher<A, Never>,
        _ b: some Publisher<B, Never>,
        _ c: some Publisher<C, Never>,
        _ d: some Publisher<D, Never>,
        _ e: some Publisher<E, Never>,
        resultSelector: @escaping (A, B, C, D, E) -> R
    ) -> AnyPublisher<R, Never> {
        Publishers.CombineLatest4(a, b, c, d)
            .combineLatest(e)
            .map { tuple4, eVal in resultSelector(tuple4.0, tuple4.1, tuple4.2, tuple4.3, eVal) }
            .eraseToAnyPublisher()
    }
    // swiftlint:enable function_parameter_count
}
