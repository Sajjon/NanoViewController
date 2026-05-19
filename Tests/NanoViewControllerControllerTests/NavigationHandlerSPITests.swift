// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@_spi(Testing) @testable import NanoViewControllerController
import NanoViewControllerCore
import NanoViewControllerNavigation
import UIKit
import XCTest

/// Tests for the `@_spi(Testing)` navigation-handler hooks on
/// ``NanoViewController``. The hooks let unit tests drive coordinator
/// routing without going through the view-model's Combine pipeline (no UI
/// taps, no text entry, no runloop drains).
///
/// These tests verify three contracts:
///
///   1. After `push(...)`, `scene.navigationHandler` is set, callable, and
///      routes through the exact same closure the Combine subscription uses.
///   2. After `modallyPresent(...)`, `scene.modalNavigationHandler` is set
///      and forwards both the step *and* a caller-provided `DismissScene`.
///   3. The push/modal hooks are mutually exclusive — a scene that was
///      pushed has a nil `modalNavigationHandler`, and vice versa.
@MainActor
final class NavigationHandlerSPITests: XCTestCase {
    // MARK: - push(...) — navigationHandler

    func test_pushScene_setsNavigationHandlerOnTheScene() {
        // Arrange
        let coordinator = TestCoordinator(navigationController: UINavigationController())
        let viewModel = SPITestViewModel()
        var routedSteps = [SPITestStep]()

        // Act
        coordinator.push(scene: SPITestScene.self, viewModel: viewModel, animated: false) {
            routedSteps.append($0)
        }

        // Assert — the scene exposes the same closure the Combine sink will fire.
        let scene = coordinator.navigationController.viewControllers.last as? SPITestScene
        XCTAssertNotNil(scene?.navigationHandler)
        XCTAssertNil(scene?.modalNavigationHandler)

        scene?.navigationHandler?(.alpha)

        XCTAssertEqual(routedSteps, [.alpha])
    }

    func test_pushScene_navigationHandlerAndCombineSinkRouteToSameClosure() {
        // Arrange — same handler should fire whether invoked directly via the
        // SPI hook or via the ViewModel's emitted step.
        let coordinator = TestCoordinator(navigationController: UINavigationController())
        let viewModel = SPITestViewModel()
        var routedSteps = [SPITestStep]()

        coordinator.push(scene: SPITestScene.self, viewModel: viewModel, animated: false) {
            routedSteps.append($0)
        }
        let scene = coordinator.navigationController.viewControllers.last as? SPITestScene

        // Act — fire the handler directly, then drive the VM through its real input.
        scene?.navigationHandler?(.alpha)
        viewModel.trigger.send(.beta)
        pumpMainRunLoop()

        // Assert — both pulses landed on the same coordinator-side handler.
        XCTAssertEqual(routedSteps, [.alpha, .beta])
    }

    // MARK: - modallyPresent(...) — modalNavigationHandler

    func test_modallyPresent_setsModalNavigationHandlerOnTheScene() {
        // Arrange
        let nav = ModalPresentCapturingNavigationController()
        let coordinator = TestCoordinator(navigationController: nav)
        let viewModel = SPITestViewModel()
        var routedSteps = [SPITestStep]()
        var dismissCallCount = 0

        // Act
        coordinator.modallyPresent(scene: SPITestScene.self, viewModel: viewModel, animated: false) { step, dismiss in
            routedSteps.append(step)
            dismiss(false, nil)
        }
        let presented = nav.presentedViewControllerCapture as? UINavigationController
        let scene = presented?.viewControllers.first as? SPITestScene

        // Assert — modal-shaped handler is present; the push-shaped one is not.
        XCTAssertNotNil(scene?.modalNavigationHandler)
        XCTAssertNil(scene?.navigationHandler)

        // Act 2 — invoke the SPI handler with a spy dismiss closure.
        let spyDismiss: DismissScene = { _, _ in dismissCallCount += 1 }
        scene?.modalNavigationHandler?(.gamma, spyDismiss)

        // Assert
        XCTAssertEqual(routedSteps, [.gamma])
        XCTAssertEqual(
            dismissCallCount,
            1,
            "modalNavigationHandler should forward the caller's DismissScene to the routing closure"
        )
    }

    func test_modalNavigationHandler_dismissForwardsAnimatedFlagAndCompletion() {
        // Arrange
        let nav = ModalPresentCapturingNavigationController()
        let coordinator = TestCoordinator(navigationController: nav)
        let viewModel = SPITestViewModel()
        var observedAnimated: Bool?
        var observedCompletionCalled = false

        coordinator.modallyPresent(scene: SPITestScene.self, viewModel: viewModel, animated: false) { _, dismiss in
            // Routing closure asks for an animated dismiss with a completion.
            dismiss(true) { observedCompletionCalled = true }
        }
        let presented = nav.presentedViewControllerCapture as? UINavigationController
        let scene = presented?.viewControllers.first as? SPITestScene

        // Act — invoke the SPI handler with a spy that records the args.
        let spy: DismissScene = { animated, completion in
            observedAnimated = animated
            completion?()
        }
        scene?.modalNavigationHandler?(.gamma, spy)

        // Assert
        XCTAssertEqual(observedAnimated, true)
        XCTAssertTrue(observedCompletionCalled)
    }
}

// MARK: - Test doubles

private enum SPITestStep: Sendable, Equatable {
    case alpha
    case beta
    case gamma
}

private struct SPITestInputFromView {}
private struct SPITestPublishers {}

private final class SPITestViewModel: AbstractViewModel<SPITestInputFromView, SPITestPublishers, SPITestStep> {
    let trigger = PassthroughSubject<SPITestStep, Never>()

    override func transform(input _: Input) -> Output<SPITestPublishers, SPITestStep> {
        let navigator = Navigator<SPITestStep>()
        return Output(
            publishers: SPITestPublishers(),
            navigation: navigator.navigation
        ) {
            trigger.sink { [navigator] in navigator.next($0) }
        }
    }
}

private final class SPITestView: UIView, ViewModelled {
    typealias ViewModel = SPITestViewModel

    var inputFromView: SPITestInputFromView {
        SPITestInputFromView()
    }

    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }
}

private final class SPITestScene: NanoViewController<SPITestView> {}

private enum SPICoordinatorStep: Sendable {
    case routed
}

private final class TestCoordinator: BaseCoordinator<SPICoordinatorStep> {
    override func start(didStart: Completion? = nil) {
        didStart?()
    }
}

private final class ModalPresentCapturingNavigationController: UINavigationController {
    private(set) var presentedViewControllerCapture: UIViewController?

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated _: Bool,
        completion: (() -> Void)? = nil
    ) {
        presentedViewControllerCapture = viewControllerToPresent
        completion?()
    }
}
