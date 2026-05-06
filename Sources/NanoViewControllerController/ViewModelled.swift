// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCombine
import NanoViewControllerCore

/// The contract every scene's root `UIView` implements to participate in the
/// reactive MVVM pipeline.
///
/// A `ViewModelled` view exposes its user-driven publishers as
/// ``inputFromView`` (read by ``SceneController``), and binds the ViewModel's
/// `OutputVM` back into UI controls via ``populate(with:)`` — returning the
/// `AnyCancellable`s so the controller can retain them for the view's
/// lifetime.
///
/// ## Example — a minimal ViewModelled view
///
/// ```swift
/// import Combine
/// import NanoViewControllerCombine
/// import NanoViewControllerController
/// import NanoViewControllerSceneViews
/// import UIKit
///
/// final class WelcomeView: BaseScrollableStackViewOwner, ContentViewProvider {
///     // Pair the view with a ViewModel — that's what `ViewModelled` requires.
///     typealias ViewModel = WelcomeViewModel
///
///     // MARK: - Subviews
///     private let headlineLabel = UILabel()
///     fileprivate let signUpButton = UIButton(type: .system)
///     fileprivate let haveAccountButton = UIButton(type: .system)
///
///     // ContentViewProvider — what to seat inside the scroll view.
///     func makeContentView() -> UIView {
///         let stack = UIStackView(arrangedSubviews: [
///             headlineLabel, signUpButton, haveAccountButton,
///         ])
///         stack.axis = .vertical
///         stack.spacing = 16
///         return stack
///     }
///
///     // MARK: - ViewModelled — describe what the View *exposes* to the VM.
///     struct InputFromView {
///         let userPressedSignUp:      AnyPublisher<Void, Never>
///         let userPressedHaveAccount: AnyPublisher<Void, Never>
///     }
///
///     var inputFromView: InputFromView {
///         InputFromView(
///             userPressedSignUp:      signUpButton.tapPublisher,
///             userPressedHaveAccount: haveAccountButton.tapPublisher
///         )
///     }
///
///     // MARK: - ViewModelled — bind the VM's output to UI controls.
///     func populate(with output: WelcomeViewModel.OutputVM) -> [AnyCancellable] {
///         [
///             output.headline      --> headlineLabel,
///             output.signUpTitle   --> signUpButton.titleBinder(for: .normal),
///         ]
///     }
/// }
/// ```
///
/// `SceneController<WelcomeView>` then handles the rest — building the
/// `Input`, calling `viewModel.transform(input:)`, and storing every
/// cancellable returned by `populate(with:)` on its own `cancellables` bag.
///
/// `@MainActor` because every conformer is a UIView subclass — main-thread
/// in the iOS 26 SDK. Inherits the isolation from ``EmptyInitializable``,
/// but the explicit attribute makes it self-documenting.
@MainActor
public protocol ViewModelled: EmptyInitializable {
    /// The ViewModel type this view is paired with.
    associatedtype ViewModel: ViewModelType

    /// Convenience alias so conforming types can declare an inner
    /// `struct InputFromView { … }` without restating the ViewModel's type.
    typealias InputFromView = ViewModel.Input.FromView

    /// User-event publishers the ViewModel consumes (taps, text changes,
    /// toggles).
    var inputFromView: InputFromView { get }

    /// Binds the ViewModel's output publishers to UI controls.
    ///
    /// Called exactly once after `transform`. The returned cancellables are
    /// retained by ``SceneController`` for the lifetime of the scene.
    ///
    /// - Parameter viewModel: The output bag returned from
    ///   ``ViewModelType/transform(input:)``.
    /// - Returns: Every `AnyCancellable` produced by the bindings; the
    ///   controller stores them so they outlive the call.
    @BindingsBuilder
    func populate(with viewModel: ViewModel.OutputVM) -> [AnyCancellable]
}

public extension ViewModelled {
    /// Default no-op so pure-output-less views (e.g. static welcome screens)
    /// don't need to implement `populate`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// final class StaticWelcomeView: BaseScrollableStackViewOwner, ContentViewProvider {
    ///     // No bindings to install — the default empty array is fine.
    ///     // (We still need the typealias and inputFromView declarations.)
    /// }
    /// ```
    @BindingsBuilder
    func populate(with _: ViewModel.OutputVM) -> [AnyCancellable] {
        []
    }
}

/// Sentinel `FromController` type used by views that don't need any
/// controller-lifecycle input.
///
/// Keeps the ViewModel generic parameter non-optional without forcing every
/// view to accept an unused ``InputFromController``. Use this when you have a
/// reusable embedded view (e.g. a counter cell) that runs without being
/// hosted by a ``SceneController``.
///
/// ## Example
///
/// ```swift
/// final class CounterViewModel: AbstractViewModel<
///     CounterInputFromView, NoControllerInput, CounterOutput
/// > {
///     // FromController is NoControllerInput — we ignore the lifecycle channel.
/// }
///
/// final class CounterView: UIView, ViewModelled {
///     typealias ViewModel = CounterViewModel
///     // … inputFromView, populate(with:)
/// }
///
/// // Embedding code can build the input without any controller plumbing:
/// let input = counterView.input             // <- convenience below
/// let output = counterVM.transform(input: input)
/// counterView.populate(with: output).forEach { $0.store(in: &cancellables) }
/// ```
public struct NoControllerInput {
    public init() {}
}

public extension ViewModelled where ViewModel.Input.FromController == NoControllerInput {
    /// Convenience: builds the ViewModel input struct with an empty
    /// controller channel for views that don't care about lifecycle events.
    var input: ViewModel.Input {
        ViewModel.Input(fromView: inputFromView, fromController: NoControllerInput())
    }
}
