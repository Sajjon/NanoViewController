// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCore
import NanoViewControllerDIPrimitives
import NanoViewControllerNavigation
import UIKit

/// The "Single-Line Controller" base class — generic scene glue that hosts
/// any `(UIView, ViewModelled)` pair without per-scene controller code.
///
/// `NanoViewController<View>`:
///
///   1. Instantiates `View` empty via ``EmptyInitializable``.
///   2. Builds an ``InputFromController`` from its own lifecycle, bar-button
///      and write-back subjects.
///   3. Stitches the View's ``ViewModelled/inputFromView`` together with that
///      controller-side input and calls ``ViewModelType/transform(input:)``
///      on the ViewModel, receiving an ``Output``.
///   4. Stores the cancellables carried in the ``Output``, then binds the
///      ``Output/publishers`` bag back into the View via
///      ``ViewModelled/populate(with:)``.
///
/// This is the load-bearing class of the package — coordinators push instances
/// of `NanoViewController<…>` directly, and you almost never need to subclass
/// it beyond declaring a concrete screen type and optional ``ControllerConfig``.
///
/// ## Example — coordinator pushing a scene
///
/// ```swift
/// final class OnboardingCoordinator: BaseCoordinator<Never> {
///     override func start(didStart: Completion? = nil) {
///         let vm = WelcomeViewModel(api: api)
///         push(scene: WelcomeScene.self, viewModel: vm) { [weak self] step in
///             // route step → next scene
///         }
///     }
/// }
/// ```
///
/// `WelcomeScene` can be an empty `NanoViewController<WelcomeView>` subclass.
/// `NanoViewController` is doing all the work generically.
///
/// ## Subclassing — when (rarely) needed
///
/// Override one of the open hooks if you need to:
///
///   * change ``rootBackgroundColor`` — your app's brand background,
///   * substitute a test ``clock`` for synchronous toast auto-dismiss,
///   * provide ``ControllerConfigProviding/config`` to set static title, bar
///     buttons, back-button behavior, and nav-bar layout.
///
/// ```swift
/// final class BrandedWelcomeScene: NanoViewController<WelcomeView>, ControllerConfigProviding {
///     static let config = ControllerConfig(
///         title: "Welcome",
///         navigationBarLayout: .opaque(brand: .primary)
///     )
///
///     override var rootBackgroundColor: UIColor { .brandBackground }
/// }
/// ```
open class NanoViewController<View: ContentView>: UIViewController {
    /// Convenience alias for the view's ViewModel type.
    public typealias ViewModel = View.ViewModel

    /// Subject fired every time the navigation-item *right* bar button is
    /// pressed. Forwarded to the ViewModel as
    /// ``InputFromController/rightBarButtonTrigger``.
    public let rightBarButtonSubject = PassthroughSubject<Void, Never>()

    /// Subject fired every time the navigation-item *left* bar button is
    /// pressed. Forwarded to the ViewModel as
    /// ``InputFromController/leftBarButtonTrigger``.
    public let leftBarButtonSubject = PassthroughSubject<Void, Never>()

    /// `@objc` target object UIKit invokes for the right bar button's action
    /// selector.
    public lazy var rightBarButtonAbstractTarget = AbstractTarget(triggerSubject: rightBarButtonSubject)

    /// `@objc` target object UIKit invokes for the left bar button's action
    /// selector.
    public lazy var leftBarButtonAbstractTarget = AbstractTarget(triggerSubject: leftBarButtonSubject)

    /// Bag of Combine subscriptions owned by this controller (navigation-bar
    /// bindings, toasts, title updates, view ↔ view-model bindings).
    /// Survives for the lifetime of the controller.
    private var cancellables = Set<AnyCancellable>()

    /// The ViewModel injected by the coordinator at construction time.
    public let viewModel: ViewModel

    /// Backing subject the controller forwards `Output.navigation` into.
    /// Exists from construction so coordinators can subscribe to
    /// ``navigation`` without an ordering dance with `bindViewToViewModel`.
    private let navigationSubject = PassthroughSubject<ViewModel.NavigationStep, Never>()

    /// The navigation publisher the coordinator subscribes to. Use this from
    /// coordinator hookup code instead of reaching into the ViewModel.
    public lazy var navigation: AnyPublisher<ViewModel.NavigationStep, Never> =
        navigationSubject.eraseToAnyPublisher()

    /// Test-only handle to the navigation handler the coordinator registered
    /// for this scene when it was pushed onto the navigation stack via
    /// ``Coordinating/push(scene:viewModel:animated:navigationPresentationCompletion:navigationHandler:)``
    /// or
    /// ``Coordinating/pushSceneInstance(_:animated:navigationPresentationCompletion:navigationHandler:)``.
    ///
    /// ## Why this exists
    ///
    /// Coordinators register routing logic inline at the call site:
    ///
    /// ```swift
    /// push(scene: PrepareScene.self, viewModel: vm) { [weak self] step in
    ///     guard let self else { return }
    ///     switch step {
    ///     case .cancel: finish()
    ///     case let .submit(payment): toReviewPayment(payment)
    ///     }
    /// }
    /// ```
    ///
    /// That handler is normally only invoked through the Combine pipeline:
    /// the ViewModel emits a `NavigationStep` from `transform`, NVC forwards
    /// it through ``navigation``, and the coordinator's `sinkOnMain`
    /// subscription dispatches it. Unit tests that just want to assert
    /// **"when `.submit(payment)` happens, `ReviewPayment` gets pushed"**
    /// would otherwise have to drive the full view → view-model → Combine
    /// chain via UIKit (taps, text entry, runloop drains) to reach that
    /// switch statement.
    ///
    /// `navigationHandler` exposes the same closure that the Combine sink is
    /// holding, so tests can synthesize the step directly:
    ///
    /// ```swift
    /// @_spi(Testing) import NanoViewControllerController
    ///
    /// func test_submitPayment_pushesReview() {
    ///     coordinator.start()
    ///     let prepare = navigationController.viewControllers.first as! PrepareScene
    ///
    ///     prepare.navigationHandler?(.submit(payment))
    ///
    ///     XCTAssertTrue(navigationController.viewControllers.last is ReviewScene)
    /// }
    /// ```
    ///
    /// ## Trade-off
    ///
    /// The test no longer verifies that the ViewModel's emitted step actually
    /// reaches the coordinator's subscription — only that the handler routes
    /// correctly once invoked. The wiring is identical across every `push`
    /// call site, so one happy-path test that drives a real Combine emission
    /// is usually enough to cover the subscription itself. Use this seam for
    /// the routing-logic tests; rely on VM-level tests for the emission
    /// contracts and a UI smoke test for the pipeline.
    ///
    /// ## Visibility
    ///
    /// Hidden behind `@_spi(Testing)` — production callers see this property
    /// as `internal` unless they opt in via `@_spi(Testing) import`. NVC and
    /// its tests can write through `internal(set)`; consumers can only read.
    ///
    /// Nil when the scene was presented modally (see ``modalNavigationHandler``)
    /// or hasn't been pushed yet.
    @_spi(Testing)
    public internal(set) var navigationHandler: ((ViewModel.NavigationStep) -> Void)?

    /// Test-only handle to the navigation handler the coordinator registered
    /// for this scene when it was presented modally via
    /// ``Coordinating/modallyPresent(scene:animated:presentationCompletion:navigationHandler:)``
    /// (or one of the modal-style overloads such as
    /// ``Coordinating/replaceAllScenes(with:animated:whenReplacingFinished:navigationHandler:)``).
    ///
    /// Same rationale as ``navigationHandler``, but the modal variant's
    /// handler signature carries an extra ``DismissScene`` parameter so the
    /// coordinator can dismiss the modal from inside the routing closure:
    ///
    /// ```swift
    /// modallyPresent(scene: ScanQRCode.self, viewModel: vm) { [weak self] step, dismiss in
    ///     switch step {
    ///     case let .scanned(intent):
    ///         dismiss(true) { self?.parent.forward(intent) }
    ///     case .cancel:
    ///         dismiss(true, nil)
    ///     }
    /// }
    /// ```
    ///
    /// In tests, pass a spy ``DismissScene`` to observe both the routing
    /// and the dismissal:
    ///
    /// ```swift
    /// var dismissCalled = false
    /// let dismiss: DismissScene = { _, completion in
    ///     dismissCalled = true
    ///     completion?()
    /// }
    /// scan.modalNavigationHandler?(.scanned(intent), dismiss)
    /// XCTAssertTrue(dismissCalled)
    /// ```
    ///
    /// Nil when the scene was pushed (see ``navigationHandler``) or hasn't
    /// been presented yet.
    @_spi(Testing)
    public internal(set) var modalNavigationHandler: ((ViewModel.NavigationStep, @escaping DismissScene) -> Void)?

    /// The Combine subscription forwarding ``navigation`` into the
    /// coordinator's routing closure (either ``navigationHandler`` or
    /// ``modalNavigationHandler``).
    ///
    /// Lives on the scene rather than the coordinator's bag so that
    /// re-subscribing through the inverse helper (push ↔ modal) cancels the
    /// previous subscription — assigning a fresh `AnyCancellable` releases
    /// (and cancels) the old one. This enforces "last subscriber wins" on
    /// the Combine route, matching the mutual-exclusivity invariant the SPI
    /// hook properties already promise.
    var navigationSubscription: AnyCancellable?

    /// Clock used to auto-dismiss toasts emitted via
    /// ``InputFromController/toastSubject``.
    ///
    /// Defaults to a real ``MainQueueClock``. Subclasses (or test fakes)
    /// override to substitute an immediate clock so toast auto-dismiss skips
    /// the runloop in tests.
    open var clock: any Clock {
        MainQueueClock()
    }

    /// Optional override-point: the colour the controller's
    /// `view.backgroundColor` is set to in `viewDidLoad`.
    ///
    /// Defaults to `.systemBackground`. Subclasses (or app-level extensions
    /// on `NanoViewController`) override this to apply a brand background.
    open var rootBackgroundColor: UIColor {
        .systemBackground
    }

    /// Instance-level chrome configuration.
    ///
    /// Override this when a controller's chrome depends on construction-time state.
    /// Otherwise conform the concrete subclass to ``ControllerConfigProviding``
    /// and declare a `static let config`.
    open var controllerConfig: ControllerConfig {
        (type(of: self) as? ControllerConfigProviding.Type)?.config ?? .default
    }

    /// Fires when `viewDidLoad` runs. Piped into
    /// ``InputFromController/viewDidLoad``.
    private let viewDidLoadSubject = PassthroughSubject<Void, Never>()

    /// Fires each time `viewWillAppear` runs.
    private let viewWillAppearSubject = PassthroughSubject<Void, Never>()

    /// Fires each time `viewDidAppear` runs.
    private let viewDidAppearSubject = PassthroughSubject<Void, Never>()

    /// Lazily-constructed root content view.
    ///
    /// The `force_cast` is safe because `View: ContentView` and
    /// `ContentView: EmptyInitializable` by convention. The cast goes through
    /// the metatype rather than calling `View()` directly because `View` is a
    /// generic constraint on a `UIView` subclass — Swift can't synthesise
    /// `View()` without the explicit metatype dance.
    private lazy var rootContentView: View =
        // swiftlint:disable:next force_cast
        (View.self as EmptyInitializable.Type).init() as! View

    // MARK: - Initialization

    /// Designated initializer.
    ///
    /// Coordinators call this with a freshly-constructed ViewModel.
    /// ``bindViewToViewModel()`` runs eagerly so the View has live publishers
    /// before `viewDidLoad`.
    ///
    /// - Parameter viewModel: The ViewModel for this scene. Owned by the controller.
    public required init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        bindViewToViewModel()
    }

    /// Unavailable — Interface Builder is not supported. Traps to enforce
    /// the programmatic-only invariant.
    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }

    // MARK: View Lifecycle

    /// Sets up window chrome (background, root view, title, bar buttons,
    /// swipe-back), then fires the `viewDidLoad` lifecycle subject so the
    /// ViewModel's pipelines see it.
    ///
    /// Static chrome is read from ``controllerConfig``. Dynamic bar-button
    /// changes still flow through ``InputFromController`` subjects.
    override open func viewDidLoad() {
        super.viewDidLoad()
        let config = controllerConfig

        // App-wide background colour goes on the controller's view (visible
        // behind the content view during animations); content view is
        // transparent so it composes against this colour rather than masking it.
        view.backgroundColor = rootBackgroundColor
        rootContentView.backgroundColor = .clear
        view.addSubview(rootContentView)
        rootContentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rootContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootContentView.topAnchor.constraint(equalTo: view.topAnchor),
            rootContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Auto-set the navigation title only if a non-empty title is provided.
        if let sceneTitle = config.title, !sceneTitle.isEmpty {
            title = sceneTitle
        }

        // Opt-in static bar-button installation. Dynamic per-screen changes go
        // through the `…BarButtonContentSubject` instead (see
        // `makeAndSubscribeToInputFromController`).
        if let rightBarButton = config.rightBarButton {
            setRightBarButtonUsing(content: rightBarButton)
        }

        if let leftBarButton = config.leftBarButton {
            setLeftBarButtonUsing(content: leftBarButton)
        }

        if config.hidesBackButton {
            navigationItem.hidesBackButton = true
        }

        navigationController?.interactivePopGestureRecognizer?.isEnabled = !config.hidesBackButton

        // Last — fire the lifecycle pulse only after all chrome is in place,
        // so any view-model handler observing `viewDidLoad` can safely assume
        // the navigation bar is configured.
        viewDidLoadSubject.send(())
    }

    /// Re-applies the navigation bar layout (in case it was changed by a
    /// previous scene) and forwards the lifecycle event.
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyLayoutIfNeeded(controllerConfig.navigationBarLayout)
        viewWillAppearSubject.send(())
    }

    /// Forwards the `viewDidAppear` lifecycle event to the ViewModel pipeline.
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewDidAppearSubject.send(())
    }

    /// Default `description` is the runtime class name — handy in logs to
    /// identify the concrete `NanoViewController<…>` specialisation without an
    /// inheritance dance.
    override open var description: String {
        "\(type(of: self))"
    }
}

// MARK: Private

private extension NanoViewController {
    /// Constructs the ViewModel-facing ``InputFromController``, eagerly
    /// subscribing the controller-side sinks (title text, toasts, dynamic
    /// bar-button updates) so the ViewModel can fire-and-forget those subjects.
    ///
    /// All sinks hop to `RunLoop.main` because they touch UIKit; `[weak self]`
    /// avoids a retain cycle with the long-lived controller-owned subjects.
    func makeAndSubscribeToInputFromController() -> InputFromController {
        let titleSubject = PassthroughSubject<String, Never>()
        let leftBarButtonContentSubject = PassthroughSubject<BarButtonContent, Never>()
        let rightBarButtonContentSubject = PassthroughSubject<BarButtonContent, Never>()
        let toastSubject = PassthroughSubject<Toast, Never>()
        // Snapshot the (overridable) clock at wiring time so the toast sink
        // closes over a single instance rather than re-resolving the
        // computed property on every emission.
        let clock = clock

        [
            // Dynamic title updates emitted by the ViewModel.
            titleSubject.receive(on: RunLoop.main).sink { [weak self] in self?.title = $0 },
            // Toasts are presented by the toast itself using `self` as the host VC.
            toastSubject.receive(on: RunLoop.main).sink { [weak self] in
                guard let self else { return }
                $0.present(using: self, clock: clock)
            },
            // Dynamic bar-button content swaps (e.g. enable/disable, change icon).
            leftBarButtonContentSubject.receive(on: RunLoop.main).sink { [weak self] in
                self?.setLeftBarButtonUsing(content: $0)
            },
            rightBarButtonContentSubject.receive(on: RunLoop.main).sink { [weak self] in
                self?.setRightBarButtonUsing(content: $0)
            },
        ].forEach { $0.store(in: &cancellables) }

        return InputFromController(
            viewDidLoad: viewDidLoadSubject.eraseToAnyPublisher(),
            viewWillAppear: viewWillAppearSubject.eraseToAnyPublisher(),
            viewDidAppear: viewDidAppearSubject.eraseToAnyPublisher(),
            leftBarButtonTrigger: leftBarButtonSubject.eraseToAnyPublisher(),
            rightBarButtonTrigger: rightBarButtonSubject.eraseToAnyPublisher(),
            titleSubject: titleSubject,
            leftBarButtonContentSubject: leftBarButtonContentSubject,
            rightBarButtonContentSubject: rightBarButtonContentSubject,
            toastSubject: toastSubject
        )
    }

    /// Performs the central wiring step:
    ///
    ///   * View → InputFromView,
    ///   * Controller → InputFromController,
    ///   * ViewModel.transform(_:) → Output<Publishers>,
    ///   * View.populate(with:) → bindings.
    ///
    /// Every cancellable carried in the ``Output`` from `transform`, plus
    /// every cancellable returned by `populate`, is stored so all bindings
    /// and side-effect subscriptions live as long as this controller does.
    func bindViewToViewModel() {
        let inputFromView = rootContentView.inputFromView
        let inputFromController = makeAndSubscribeToInputFromController()

        let input = ViewModel.Input(fromView: inputFromView, fromController: inputFromController)
        let output = viewModel.transform(input: input)

        cancellables.formUnion(output.cancellables)
        cancellables.formUnion(rootContentView.populate(with: output.publishers))

        // Forward navigation through the controller's own subject so coordinators
        // see a stable publisher regardless of when they subscribe. The upstream
        // (typically a `Navigator` constructed inside `transform`) stays alive
        // via the `[navigator]` captures inside `output.cancellables`.
        output.navigation
            .subscribe(navigationSubject)
            .store(in: &cancellables)
    }

    /// Drives ``NavigationBarLayoutingNavigationController`` to apply the
    /// right nav-bar layout for the current scene each time it appears.
    ///
    /// Logic ladder:
    ///   1. No nav controller? Nothing to do.
    ///   2. Nav controller is the wrong class? Programmer error — crash loudly.
    ///   3. Controller doesn't own a layout? No-op (the previous layout stays).
    ///   4. Same layout as last applied? Skip the work (avoid pointless animations).
    ///   5. Otherwise apply the new layout.
    func applyLayoutIfNeeded(_ layout: NavigationBarLayout?) {
        guard let layout else { return }
        guard let navigationController else { return }
        guard let barLayoutingNavController = navigationController as? NavigationBarLayoutingNavigationController else {
            incorrectImplementation(
                "navigationController should be instance of `NavigationBarLayoutingNavigationController`"
            )
        }

        if let lastLayout = barLayoutingNavController.lastLayout {
            guard layout != lastLayout else { return }
            barLayoutingNavController.applyLayout(layout)
        } else {
            barLayoutingNavController.applyLayout(layout)
        }
    }
}

@MainActor
protocol ControllerConfigReadable: AnyObject {
    var controllerConfig: ControllerConfig { get }
}

extension NanoViewController: ControllerConfigReadable {}
