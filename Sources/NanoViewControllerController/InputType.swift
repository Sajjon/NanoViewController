// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Foundation

/// A ViewModel's combined input contract.
///
/// Every ``ViewModelType`` consumes one `Input`. The `Input` is split into two
/// channels by design:
///
///   * ``fromView`` — user-intent events (taps, text changes, toggle state).
///     Owned by the View, exposed as `inputFromView`.
///   * ``fromController`` — controller lifecycle events plus *write-back*
///     subjects (title updates, toast dispatch, dynamic bar-button content).
///     Owned by ``NanoViewController``, exposed as ``InputFromController``.
///
/// Splitting them this way keeps the View free of any UIKit-controller knowledge
/// and lets the ViewModel react to lifecycle events (e.g. fetch on
/// `viewWillAppear`) without forcing every View to surface them.
///
/// You almost never implement this protocol directly — ``AbstractViewModel/Input``
/// is the synthesised conformance every concrete ViewModel inherits.
///
/// ## Example — synthesised Input on an `AbstractViewModel` subclass
///
/// ```swift
/// import Combine
/// import NanoViewControllerCombine
/// import NanoViewControllerController
/// import NanoViewControllerCore
///
/// final class HomeViewModel: AbstractViewModel<
///     HomeInputFromView,
///     HomeViewModel.Publishers,
///     HomeStep
/// > {
///     // `Input` here is `AbstractViewModel.Input`, with
///     //   FromView       = HomeInputFromView
///     //   fromController = InputFromController       (pinned by the protocol)
///     override func transform(input: Input) -> Output<Publishers, HomeStep> {
///         // Trigger an initial fetch the first time the controller appears.
///         let initialLoad = input.fromController.viewWillAppear
///             .first()
///             .flatMapLatest { [api] _ in api.fetchHome().replaceErrorWithEmpty() }
///
///         // The user-driven channel.
///         let userPullToRefresh = input.fromView.pullToRefresh
///             .flatMapLatest { [api] _ in api.fetchHome().replaceErrorWithEmpty() }
///
///         let items = Publishers.Merge(initialLoad, userPullToRefresh).map { $0.items }
///
///         return Output(
///             publishers: Publishers(items: items.eraseToAnyPublisher()),
///             navigation: Empty().eraseToAnyPublisher()
///         ) {
///             // Push the title back through the controller channel.
///             input.fromController.viewDidLoad
///                 .map { "Home" }
///                 .sink { input.fromController.titleSubject.send($0) }
///         }
///     }
/// }
/// ```
///
/// ## Example — building an `Input` in a unit test
///
/// ```swift
/// import Combine
/// import NanoViewControllerController
///
/// // Stand up a synthetic Input so we can drive the ViewModel from a test.
/// let usernameSubject = CurrentValueSubject<String, Never>("")
/// let passwordSubject = CurrentValueSubject<String, Never>("")
/// let tapSubject      = PassthroughSubject<Void, Never>()
///
/// // Build an empty InputFromController inline — no test-helper needed.
/// let titleSubject  = PassthroughSubject<String, Never>()
/// let leftSubject   = PassthroughSubject<BarButtonContent, Never>()
/// let rightSubject  = PassthroughSubject<BarButtonContent, Never>()
/// let toastSubject  = PassthroughSubject<Toast, Never>()
/// let fromController = InputFromController(
///     viewDidLoad:                    Empty().eraseToAnyPublisher(),
///     viewWillAppear:                 Empty().eraseToAnyPublisher(),
///     viewDidAppear:                  Empty().eraseToAnyPublisher(),
///     leftBarButtonTrigger:           Empty().eraseToAnyPublisher(),
///     rightBarButtonTrigger:          Empty().eraseToAnyPublisher(),
///     titleSubject:                   titleSubject,
///     leftBarButtonContentSubject:    leftSubject,
///     rightBarButtonContentSubject:   rightSubject,
///     toastSubject:                   toastSubject
/// )
///
/// let input = SignUpViewModel.Input(
///     fromView: SignUpInputFromView(
///         username:     usernameSubject.eraseToAnyPublisher(),
///         password:     passwordSubject.eraseToAnyPublisher(),
///         signUpTapped: tapSubject.eraseToAnyPublisher()
///     ),
///     fromController: fromController
/// )
///
/// let output = SignUpViewModel(service: stubService).transform(input: input)
///
/// // Drive the form, assert on the published outputs.
/// usernameSubject.send("alex")
/// passwordSubject.send("hunter22")
/// tapSubject.send(())
/// ```
///
/// `@MainActor` because the input is constructed and consumed inside
/// `NanoViewController` (a `UIViewController` subclass), so the whole
/// view-model pipeline lives on the main actor.
@MainActor
public protocol InputType {
    /// The view-driven publishers — taps, text, toggle state, etc. Defined as a
    /// `struct` nested inside the concrete View type.
    associatedtype FromView

    /// The view channel.
    var fromView: FromView { get }

    /// The controller channel — pinned to ``InputFromController``, the
    /// concrete write-back surface every ``NanoViewController`` builds.
    var fromController: InputFromController { get }

    /// Designated initializer.
    ///
    /// ``NanoViewController`` constructs this struct on the ViewModel's behalf by
    /// combining the `View.inputFromView` property with the lifecycle-derived
    /// ``InputFromController`` it builds itself. Tests can call this directly
    /// when wiring a synthetic `Input`.
    init(fromView: FromView, fromController: InputFromController)
}
