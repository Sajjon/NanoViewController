// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
import Foundation

/// The controller-lifecycle + write-back surface every scene-bound ViewModel
/// receives through `Input.fromController`.
///
/// Publishers (``viewDidLoad``, bar-button triggers) flow **from** the
/// ``NanoViewController`` **into** the ViewModel. Subjects (``titleSubject``,
/// ``toastSubject``, etc.) flow the other direction: the ViewModel `send`s
/// values to drive UI the controller owns.
///
/// ## Example — using all four directions in a single ViewModel transform
///
/// ```swift
/// import Combine
/// import NanoViewControllerCombine
/// import NanoViewControllerController
/// import NanoViewControllerCore
/// import NanoViewControllerNavigation
///
/// final class HomeViewModel: AbstractViewModel<
///     HomeInputFromView,
///     HomeViewModel.Publishers,
///     HomeStep
/// > {
///     override func transform(input: Input) -> Output<Publishers, HomeStep> {
///         let navigator = Navigator<HomeStep>()
///
///         // 1. Lifecycle in: kick off an initial fetch on first appear.
///         let home = input.fromController.viewWillAppear
///             .first()
///             .flatMapLatest { [api] _ in api.fetchHome().replaceErrorWithEmpty() }
///             .share()
///
///         return Output(
///             publishers: Publishers(home: home.eraseToAnyPublisher()),
///             navigation: navigator.navigation
///         ) {
///             // 2. Title write-back: change the title each time the user picks a tab.
///             input.fromView.tabSelected
///                 .map { tab in tab.localizedTitle }
///                 .sink { input.fromController.titleSubject.send($0) }
///
///             // 3. Bar-button trigger in: the navigation-bar Edit button was tapped.
///             input.fromController.rightBarButtonTrigger
///                 .sink { [navigator] in navigator.next(.userTappedEdit) }
///
///             // 4. Toast write-back: tell the user when a sync completes.
///             input.fromView.userTappedSync
///                 .flatMapLatest { [api] _ in api.sync().replaceErrorWithEmpty() }
///                 .sink { input.fromController.toastSubject.send("Synced") }
///         }
///     }
/// }
/// ```
///
/// The ``NanoViewController`` handles all the UIKit side-effects: it sets the
/// title on the navigation item when ``titleSubject`` fires, dispatches a
/// `UIAlertController`-based toast when ``toastSubject`` fires, and so on.
public struct InputFromController {
    /// Fires once, right after the controller's `viewDidLoad`.
    ///
    /// Use this rather than initializing in the ViewModel's `init` if you
    /// need the navigation bar to be configured before your handler runs.
    public let viewDidLoad: AnyPublisher<Void, Never>

    /// Fires every time the controller is about to appear on screen.
    public let viewWillAppear: AnyPublisher<Void, Never>

    /// Fires every time the controller finishes appearing on screen.
    public let viewDidAppear: AnyPublisher<Void, Never>

    /// Fires when the user taps the left navigation-bar button.
    public let leftBarButtonTrigger: AnyPublisher<Void, Never>

    /// Fires when the user taps the right navigation-bar button.
    public let rightBarButtonTrigger: AnyPublisher<Void, Never>

    /// The ViewModel pushes a new navigation-bar title here to update the
    /// controller. Each emission is forwarded to `controller.title` on the
    /// main thread.
    public let titleSubject: PassthroughSubject<String, Never>

    /// The ViewModel pushes left-bar-button content (icon / title / enabled
    /// state) here. Each emission is wired up via
    /// ``NanoViewController/setLeftBarButtonUsing(content:)``.
    public let leftBarButtonContentSubject: PassthroughSubject<BarButtonContent, Never>

    /// The ViewModel pushes right-bar-button content here. Same wiring as
    /// ``leftBarButtonContentSubject``.
    public let rightBarButtonContentSubject: PassthroughSubject<BarButtonContent, Never>

    /// The ViewModel pushes ``Toast`` notifications here for the controller
    /// to display.
    public let toastSubject: PassthroughSubject<Toast, Never>

    /// Memberwise initialiser — public so ``NanoViewController`` (or test fakes)
    /// can build the struct from the right side of the package boundary.
    public init(
        viewDidLoad: AnyPublisher<Void, Never>,
        viewWillAppear: AnyPublisher<Void, Never>,
        viewDidAppear: AnyPublisher<Void, Never>,
        leftBarButtonTrigger: AnyPublisher<Void, Never>,
        rightBarButtonTrigger: AnyPublisher<Void, Never>,
        titleSubject: PassthroughSubject<String, Never>,
        leftBarButtonContentSubject: PassthroughSubject<BarButtonContent, Never>,
        rightBarButtonContentSubject: PassthroughSubject<BarButtonContent, Never>,
        toastSubject: PassthroughSubject<Toast, Never>
    ) {
        self.viewDidLoad = viewDidLoad
        self.viewWillAppear = viewWillAppear
        self.viewDidAppear = viewDidAppear
        self.leftBarButtonTrigger = leftBarButtonTrigger
        self.rightBarButtonTrigger = rightBarButtonTrigger
        self.titleSubject = titleSubject
        self.leftBarButtonContentSubject = leftBarButtonContentSubject
        self.rightBarButtonContentSubject = rightBarButtonContentSubject
        self.toastSubject = toastSubject
    }
}
