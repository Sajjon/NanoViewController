// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerController
import NanoViewControllerCore
import NanoViewControllerNavigation
import UIKit
import XCTest

@MainActor
final class CoordinatorHelperTests: XCTestCase {
    func test_startCoordinator_appendStartsChildAndRoutesNavigation() {
        let parent = TestCoordinator(navigationController: UINavigationController())
        let child = TestCoordinator(navigationController: UINavigationController())
        var didStart = false
        var routedSteps = [TestStep]()

        parent.start(
            coordinator: child,
            didStart: { didStart = true },
            navigationHandler: { routedSteps.append($0) }
        )
        child.navigator.next(.first)
        pumpMainRunLoop()

        XCTAssertEqual(parent.childCoordinators.count, 1)
        XCTAssertTrue(parent.childCoordinators.first === child)
        XCTAssertEqual(child.startCount, 1)
        XCTAssertTrue(didStart)
        XCTAssertEqual(routedSteps, [.first])
    }

    func test_startCoordinator_replaceClearsStackBeforeStartingChild() {
        let nav = PresentedOverrideNavigationController()
        nav.viewControllers = [UIViewController()]
        let presented = DismissCapturingViewController()
        nav.presentedViewControllerOverride = presented
        let parent = TestCoordinator(navigationController: nav)
        let child = TestCoordinator(navigationController: UINavigationController())
        var didStart = false

        parent.start(
            coordinator: child,
            transition: .replace,
            didStart: { didStart = true },
            navigationHandler: { _ in }
        )
        pumpMainRunLoop()

        XCTAssertTrue(presented.didDismiss)
        XCTAssertEqual(nav.viewControllers.count, 0)
        XCTAssertEqual(parent.childCoordinators.count, 1)
        XCTAssertTrue(parent.childCoordinators.first === child)
        XCTAssertEqual(child.startCount, 1)
        XCTAssertTrue(didStart)
    }

    func test_startCoordinator_replaceWithoutPresentedControllerClearsStackBeforeStartingChild() {
        let nav = UINavigationController(rootViewController: UIViewController())
        let parent = TestCoordinator(navigationController: nav)
        let child = TestCoordinator(navigationController: UINavigationController())
        var didStart = false

        parent.start(
            coordinator: child,
            transition: .replace,
            didStart: { didStart = true },
            navigationHandler: { _ in }
        )
        pumpMainRunLoop()

        XCTAssertTrue(nav.viewControllers.isEmpty)
        XCTAssertEqual(parent.childCoordinators.count, 1)
        XCTAssertTrue(parent.childCoordinators.first === child)
        XCTAssertEqual(child.startCount, 1)
        XCTAssertTrue(didStart)
    }

    func test_presentModalCoordinatorStartsPresentsRoutesAndRemovesChild() {
        let nav = PresentCapturingNavigationController()
        let parent = TestCoordinator(navigationController: nav)
        var child: TestCoordinator?
        var didStart = false
        var routedSteps = [TestStep]()

        parent.presentModalCoordinator(
            makeCoordinator: { modalNavigationController in
                let coordinator = TestCoordinator(navigationController: modalNavigationController)
                child = coordinator
                return coordinator
            },
            didStart: { didStart = true },
            navigationHandler: { step, dismiss in
                routedSteps.append(step)
                dismiss(false)
            }
        )

        XCTAssertEqual(parent.childCoordinators.count, 1)
        XCTAssertTrue(nav.presentedViewControllerCapture is NavigationBarLayoutingNavigationController)
        XCTAssertEqual(child?.startCount, 1)
        XCTAssertTrue(didStart)

        child?.navigator.next(.second)
        pumpMainRunLoop()

        XCTAssertEqual(routedSteps, [.second])
        XCTAssertTrue(parent.childCoordinators.isEmpty)
    }

    func test_stackHelpersFindRemoveAndResolveTopMostCoordinatorAndScene() {
        let topViewController = UIViewController()
        let nav = UINavigationController(rootViewController: UIViewController())
        let grandchildNavigationController = UINavigationController(rootViewController: UIViewController())
        grandchildNavigationController.pushViewController(topViewController, animated: false)
        let parent = TestCoordinator(navigationController: nav)
        let child = TestCoordinator(navigationController: UINavigationController())
        let grandchild = TestCoordinator(navigationController: grandchildNavigationController)
        parent.childCoordinators = [child]
        child.childCoordinators = [grandchild]

        XCTAssertEqual(parent.firstIndexOf(child: child), 0)
        XCTAssertTrue(parent.topMostCoordinator === grandchild)
        XCTAssertTrue(parent.topMostScene === topViewController)

        parent.remove(childCoordinator: child)

        XCTAssertTrue(parent.childCoordinators.isEmpty)
        XCTAssertTrue(parent.topMostCoordinator === parent)
    }

    func test_topMostSceneHandlesPresentedPlainAndNavigationControllers() {
        let nav = PresentedOverrideNavigationController(rootViewController: UIViewController())
        let coordinator = TestCoordinator(navigationController: nav)
        let plainPresented = UIViewController()
        let modalTop = UIViewController()
        let modalNavigation = UINavigationController(rootViewController: modalTop)

        nav.presentedViewControllerOverride = plainPresented
        XCTAssertTrue(coordinator.topMostScene === plainPresented)

        nav.presentedViewControllerOverride = modalNavigation
        XCTAssertTrue(coordinator.topMostScene === modalTop)
    }
}

@MainActor
final class CoordinatorNavigationHelperTests: XCTestCase {
    func test_navigationStackHelpers() {
        let nav = UINavigationController()
        let root = UIViewController()
        let second = MarkerViewController()
        let replacement = OtherViewController()
        let coordinator = TestCoordinator(navigationController: nav)
        var rootCompletion = false
        var pushCompletion = false
        var replacementCompletion = false
        var popCompletion = false

        nav.setRootViewControllerIfEmptyElsePush(viewController: root, animated: true) {
            rootCompletion = true
        }
        pumpMainRunLoop()
        nav.setRootViewControllerIfEmptyElsePush(viewController: second, animated: false) {
            pushCompletion = true
        }
        pumpMainRunLoop()

        XCTAssertEqual(nav.viewControllers, [root, second])
        XCTAssertTrue(rootCompletion)
        XCTAssertTrue(pushCompletion)
        XCTAssertTrue(coordinator.isTopmost(scene: MarkerViewController.self))
        XCTAssertFalse(coordinator.isTopmost(scene: OtherViewController.self))

        nav.setRootViewControllerIfEmptyElsePush(
            viewController: replacement,
            animated: false,
            forceReplaceAllVCsInsteadOfPush: true
        ) {
            replacementCompletion = true
        }
        pumpMainRunLoop()

        XCTAssertEqual(nav.viewControllers, [replacement])
        XCTAssertTrue(replacementCompletion)
        XCTAssertTrue(coordinator.isTopmost(scene: OtherViewController.self))

        nav.pushViewController(second, animated: false)
        nav.popToRootViewController(animated: false) {
            popCompletion = true
        }
        pumpMainRunLoop()

        XCTAssertEqual(nav.viewControllers, [replacement])
        XCTAssertTrue(popCompletion)
    }

    func test_pushPresentAndReplaceSceneHelpersRouteSceneNavigation() {
        let nav = PresentCapturingNavigationController()
        let coordinator = TestCoordinator(navigationController: nav)
        let pushedViewModel = RouteViewModel()
        let modalViewModel = RouteViewModel()
        let replacementViewModel = RouteViewModel()
        var pushedSteps = [RouteStep]()
        var modalSteps = [RouteStep]()
        var replacementSteps = [RouteStep]()

        coordinator.push(scene: RouteScene.self, viewModel: pushedViewModel, animated: false) {
            pushedSteps.append($0)
        }
        pushedViewModel.trigger.send(())
        pumpMainRunLoop()

        coordinator.modallyPresent(scene: RouteScene.self, viewModel: modalViewModel, animated: false) { step, dismiss in
            modalSteps.append(step)
            dismiss(false, nil)
        }
        modalViewModel.trigger.send(())
        pumpMainRunLoop()

        coordinator.replaceAllScenes(with: RouteScene.self, viewModel: replacementViewModel, animated: false) { step, dismiss in
            replacementSteps.append(step)
            dismiss(false, nil)
        }
        replacementViewModel.trigger.send(())
        pumpMainRunLoop()

        XCTAssertEqual(pushedSteps, [.triggered])
        XCTAssertEqual(modalSteps, [.triggered])
        XCTAssertEqual(replacementSteps, [.triggered])
        XCTAssertTrue(nav.presentedViewControllerCapture is NavigationBarLayoutingNavigationController)
        XCTAssertTrue(nav.viewControllers.last is RouteScene)
    }

    func test_navigatorCanEmitFromBackgroundThread() {
        let navigator = Navigator<TestStep>()
        let expectation = expectation(description: "navigation delivered")
        var receivedSteps = [TestStep]()
        let cancellable = navigator.navigation.sink {
            receivedSteps.append($0)
            expectation.fulfill()
        }

        DispatchQueue.global().async {
            navigator.next(.first)
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedSteps, [.first])
        _ = cancellable
    }
}

private enum TestStep: Sendable {
    case first
    case second
}

private final class TestCoordinator: BaseCoordinator<TestStep> {
    private(set) var startCount = 0

    override func start(didStart: Completion? = nil) {
        startCount += 1
        didStart?()
    }
}

private final class PresentCapturingNavigationController: UINavigationController {
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

private final class PresentedOverrideNavigationController: UINavigationController {
    var presentedViewControllerOverride: UIViewController?

    override var presentedViewController: UIViewController? {
        presentedViewControllerOverride ?? super.presentedViewController
    }
}

private final class DismissCapturingViewController: UIViewController {
    private(set) var didDismiss = false

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        didDismiss = true
        completion?()
    }
}

private final class MarkerViewController: UIViewController {}
private final class OtherViewController: UIViewController {}

private enum RouteStep: Sendable {
    case triggered
}

private struct RouteInputFromView {}
private struct RoutePublishers {}

private final class RouteViewModel: AbstractViewModel<RouteInputFromView, RoutePublishers, RouteStep> {
    let trigger = PassthroughSubject<Void, Never>()

    override func transform(input _: Input) -> Output<RoutePublishers, RouteStep> {
        let navigator = Navigator<RouteStep>()
        return Output(
            publishers: RoutePublishers(),
            navigation: navigator.navigation
        ) {
            trigger.sink { [navigator] in navigator.next(.triggered) }
        }
    }
}

private final class RouteView: UIView, ViewModelled {
    typealias ViewModel = RouteViewModel

    var inputFromView: RouteInputFromView {
        RouteInputFromView()
    }

    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }
}

private final class RouteScene: NanoViewController<RouteView> {}
