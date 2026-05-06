// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import Foundation

/// Abstract base class supplying the boilerplate every concrete ViewModel needs.
///
/// `AbstractViewModel` provides:
///
///   * a ``cancellables`` `Set<AnyCancellable>` for `transform` implementations
///     to store subscriptions in,
///   * a synthesised nested ``Input`` struct conforming to ``InputType``, and
///   * an open `transform(input:)` method that traps if not overridden — so
///     forgetting to override surfaces immediately at runtime.
///
/// The class is generic over three slots:
///
///   * `FromView` — the view-driven publisher struct the View exposes.
///   * `FromController` — the controller-driven channel; usually
///     ``InputFromController`` (and that's what ``BaseViewModel`` pins).
///   * `OutputFromViewModel` — the bag of publishers returned by `transform`.
///
/// Most consumers should subclass ``BaseViewModel`` instead — that variant
/// fixes `FromController` to ``InputFromController`` and adds a typed
/// `Navigator<Step>`, which is what 99% of scenes need. Subclass
/// `AbstractViewModel` directly only when you need a non-standard
/// `FromController` (e.g. a view that doesn't run on a ``SceneController`` at
/// all and uses ``NoControllerInput``).
///
/// ## Example — a screen-less ViewModel for a self-contained view
///
/// ```swift
/// import Combine
/// import NanoViewControllerCore
///
/// /// View-driven channel for a tiny standalone counter view.
/// struct CounterInputFromView {
///     let increment: AnyPublisher<Void, Never>
///     let decrement: AnyPublisher<Void, Never>
/// }
///
/// /// Bindings back to UILabel/UIButton in the view.
/// struct CounterOutput {
///     let countText: AnyPublisher<String, Never>
/// }
///
/// /// No SceneController in play — this view is embedded inside another screen.
/// /// We use NoControllerInput as the controller channel.
/// final class CounterViewModel: AbstractViewModel<
///     CounterInputFromView,
///     NoControllerInput,
///     CounterOutput
/// > {
///     override func transform(input: Input) -> CounterOutput {
///         let count = Publishers.Merge(
///             input.fromView.increment.map { +1 },
///             input.fromView.decrement.map { -1 }
///         )
///         .scan(0, +)
///         .prepend(0)
///
///         return CounterOutput(
///             countText: count.map { String($0) }.eraseToAnyPublisher()
///         )
///     }
/// }
/// ```
///
/// In tests you can drive the ViewModel without any UIKit:
///
/// ```swift
/// let inc = PassthroughSubject<Void, Never>()
/// let dec = PassthroughSubject<Void, Never>()
/// let vm  = CounterViewModel()
/// let out = vm.transform(input: CounterViewModel.Input(
///     fromView:       CounterInputFromView(increment: inc.eraseToAnyPublisher(),
///                                          decrement: dec.eraseToAnyPublisher()),
///     fromController: NoControllerInput()
/// ))
/// var collected: [String] = []
/// out.countText.sink { collected.append($0) }.store(in: &vm.cancellables)
///
/// inc.send(()); inc.send(()); dec.send(())
/// XCTAssertEqual(collected, ["0", "1", "2", "1"])
/// ```
///
/// `@MainActor` because it conforms to ``ViewModelType``, which is itself
/// `@MainActor`. View-models in this package are inherently main-thread —
/// they're owned by `SceneController` (a `UIViewController` subclass) and
/// their `transform(input:)` runs on the main actor.
@MainActor
open class AbstractViewModel<FromView, FromController, OutputFromViewModel>: ViewModelType {
    /// Bag of Combine subscriptions owned by this ViewModel.
    ///
    /// `transform` implementations call `.store(in: &cancellables)` on every
    /// subscription they create so the subscriptions outlive the `transform`
    /// call and are deinitialized together with the ViewModel itself.
    public var cancellables = Set<AnyCancellable>()

    /// The concrete ``InputType`` Swift synthesizes for each `AbstractViewModel`
    /// specialisation.
    ///
    /// `SceneController` constructs this struct by combining the View's
    /// `inputFromView` with the lifecycle-derived ``InputFromController`` it
    /// owns, and hands it to ``transform(input:)``.
    public struct Input: InputType {
        /// Controller-lifecycle + write-back subjects channel.
        public let fromController: FromController

        /// User-driven publishers channel (taps, text, toggles).
        public let fromView: FromView

        /// Designated initializer.
        ///
        /// `SceneController` calls this to stitch together the two input
        /// channels before handing the struct to `transform`. Tests call it
        /// directly when building synthetic input.
        public init(fromView: FromView, fromController: FromController) {
            self.fromView = fromView
            self.fromController = fromController
        }
    }

    /// Designated initialiser — public so consumer subclasses can call `super.init()`.
    public init() {}

    /// Runs the ViewModel's business logic — must be overridden by subclasses.
    ///
    /// The default implementation traps via the ``abstract`` helper to surface
    /// a missing override at runtime instead of silently returning a default
    /// value (which would break scene wiring further down the line).
    ///
    /// - Parameter input: The pre-stitched ``Input`` with both channels.
    /// - Returns: A bag of publishers the view binds to UI controls.
    open func transform(input _: Input) -> OutputFromViewModel {
        abstract
    }
}
