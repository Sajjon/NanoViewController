// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import NanoViewControllerCombine
import NanoViewControllerCore

/// The contract every scene's root `UIView` implements to participate in the
/// reactive MVVM pipeline.
///
/// A `ViewModelled` view exposes its user-driven publishers as `inputFromView`
/// (read by `SceneController`), and binds the ViewModel's `OutputVM` back into
/// UI controls via `populate(with:)` — returning the `AnyCancellable`s so the
/// controller can retain them for the view's lifetime.
///
/// ## Writing `populate(with:)`
///
/// `populate(with:)` is annotated with ``BindingsBuilder``, so conformers can
/// write the body as a sequence of `-->` statements (no array literal, no
/// trailing commas, full `if`/`for`/`switch` support):
///
/// ```swift
/// public func populate(with output: ViewModel.Output) -> [AnyCancellable] {
///     output.isSubmitEnabled --> submitButton.isEnabledBinder
///     output.loadingText     --> submitButton.titleBinder(for: .normal)
///     output.isLoading       --> spinner.isAnimatingBinder
///
///     // Conditional bindings work natively — no array splicing.
///     if FeatureFlags.showDebugLabels {
///         output.isLoading.map(String.init) --> debugLabel.textBinder
///     }
/// }
/// ```
///
/// The legacy array-literal form keeps working — the builder accepts
/// `[AnyCancellable]` directly via `buildExpression(_:)`:
///
/// ```swift
/// public func populate(with output: ViewModel.Output) -> [AnyCancellable] {
///     [
///         output.title --> titleLabel,
///         output.body  --> bodyLabel,
///     ]
/// }
/// ```
///
/// `@MainActor` because every conformer is a UIView subclass (which becomes
/// `@MainActor` in the iOS 26 SDK). `inputFromView` and `populate(with:)`
/// both touch UIKit state, so the annotation matches reality and lets
/// conformances pass under Swift 6 strict concurrency.
@MainActor
public protocol ViewModelled: EmptyInitializable {
    /// The ViewModel type this view is paired with.
    associatedtype ViewModel: ViewModelType

    /// Convenience alias so conforming types can declare an inner
    /// `struct InputFromView {…}` without restating the ViewModel's type.
    typealias InputFromView = ViewModel.Input.FromView

    /// User-event publishers the ViewModel consumes (taps, text changes, toggles).
    var inputFromView: InputFromView { get }

    /// Binds the ViewModel's output publishers to UI controls.
    ///
    /// Annotated with ``BindingsBuilder`` so the body can be written as a
    /// sequence of `-->` statements (the builder collects them into the
    /// `[AnyCancellable]` shape the protocol requires). See the type-level
    /// docs for both the builder form and the legacy array-literal form.
    ///
    /// Called exactly once after `transform`. The returned cancellables are
    /// retained by the `SceneController` for the lifetime of the scene.
    @BindingsBuilder
    func populate(with viewModel: ViewModel.OutputVM) -> [AnyCancellable]
}

public extension ViewModelled {
    /// Default no-op so pure-output-less views (e.g. static welcome screens) don't
    /// need to implement `populate`.
    @BindingsBuilder
    func populate(with _: ViewModel.OutputVM) -> [AnyCancellable] {}
}

/// Sentinel `FromController` type used by views that don't need any controller-
/// lifecycle input — keeps the ViewModel generic parameter non-optional without
/// forcing every view to accept an unused `InputFromController`.
public struct NoControllerInput {
    public init() {}
}

public extension ViewModelled where ViewModel.Input.FromController == NoControllerInput {
    /// Convenience: builds the ViewModel input struct with an empty controller
    /// channel for views that don't care about lifecycle events.
    var input: ViewModel.Input {
        ViewModel.Input(fromView: inputFromView, fromController: NoControllerInput())
    }
}
