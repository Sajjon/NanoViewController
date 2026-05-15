// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine

/// `@resultBuilder` that turns a block of binding statements into the
/// `[AnyCancellable]` shape ``ViewModelled/populate(with:)`` returns.
///
/// Lets you write:
///
/// ```swift
/// public func populate(with publishers: ViewModel.Publishers) -> [AnyCancellable] {
///     publishers.isSubmitEnabled --> submitButton.isEnabledBinder
///     publishers.loadingText     --> submitButton.titleBinder(for: .normal)
///     publishers.isLoading       --> spinner.isAnimatingBinder
/// }
/// ```
///
/// instead of the array-literal form:
///
/// ```swift
/// public func populate(with publishers: ViewModel.Publishers) -> [AnyCancellable] {
///     [
///         publishers.isSubmitEnabled --> submitButton.isEnabledBinder,
///         publishers.loadingText     --> submitButton.titleBinder(for: .normal),
///         publishers.isLoading       --> spinner.isAnimatingBinder,
///     ]
/// }
/// ```
///
/// ## Why a result builder?
///
///   * **No trailing-comma surprises** — array literals make a forgotten `,`
///     look like a syntactically-valid concatenation; the builder block makes
///     each binding a statement.
///   * **`if` / `if let` / `switch` / `for`-loop bindings** — control flow
///     reads naturally instead of `if-let`-then-array-splice gymnastics.
///   * **Mix singletons and arrays freely** — a helper that returns
///     `[AnyCancellable]` (e.g. wiring up a sub-component's bindings) can be
///     used inside the same block as single `-->` bindings.
///
/// ## Example — conditional bindings
///
/// ```swift
/// public func populate(with publishers: ViewModel.Publishers) -> [AnyCancellable] {
///     publishers.isSubmitEnabled --> submitButton.isEnabledBinder
///     publishers.loadingText     --> submitButton.titleBinder(for: .normal)
///     publishers.isLoading       --> spinner.isAnimatingBinder
///
///     // Debug-only: wire the loading state into a label so it shows up
///     // in screenshots / UI tests. The builder handles `if` natively;
///     // there's no `[a, b] + (debug ? [c] : [])` splicing.
///     if FeatureFlags.showDebugLabels {
///         // The `-->` overloads accept any `Publisher<…, Never>`, so the
///         // chained `.map { … }` drops in directly — no `.eraseToAnyPublisher()`.
///         publishers.isLoading.map(String.init) --> debugLabel.textBinder
///     }
///
///     // Forward several bindings from a sub-component as one expression.
///     headerView.populate(with: publishers.header)    // returns [AnyCancellable]
/// }
/// ```
///
/// ``ViewModelled/populate(with:)`` is annotated with this builder, so any
/// conformer's implementation gets the transformation automatically — no need
/// to repeat the attribute, and the array-literal form keeps working
/// (`buildExpression(_:)` accepts `[AnyCancellable]` directly).
@resultBuilder
public enum BindingsBuilder {
    /// The partial-result type carried through every builder phase.
    public typealias PartialResult = [AnyCancellable]

    /// Lifts a single `-->` result (an `AnyCancellable`) into a partial result.
    public static func buildExpression(_ expression: AnyCancellable) -> PartialResult {
        [expression]
    }

    /// Accepts a pre-built array of cancellables — lets a helper that returns
    /// `[AnyCancellable]` (or a literal `[a, b, c]`) plug straight in.
    public static func buildExpression(_ expression: PartialResult) -> PartialResult {
        expression
    }

    /// Combines the statements of a `{ … }` block in source order.
    public static func buildBlock(_ components: PartialResult...) -> PartialResult {
        components.flatMap { $0 }
    }

    /// `if`-without-`else` — emit nothing when the condition is false.
    public static func buildOptional(_ component: PartialResult?) -> PartialResult {
        component ?? []
    }

    /// `if/else` — taken branch.
    public static func buildEither(first component: PartialResult) -> PartialResult {
        component
    }

    /// `if/else` — not-taken branch.
    public static func buildEither(second component: PartialResult) -> PartialResult {
        component
    }

    /// `for`-loop bindings.
    public static func buildArray(_ components: [PartialResult]) -> PartialResult {
        components.flatMap { $0 }
    }

    /// `if #available(...)` bindings.
    public static func buildLimitedAvailability(_ component: PartialResult) -> PartialResult {
        component
    }
}
