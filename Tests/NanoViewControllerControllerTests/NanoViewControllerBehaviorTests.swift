// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
@testable import NanoViewControllerController
import NanoViewControllerCore
import NanoViewControllerNavigation
import UIKit
import XCTest

@MainActor
final class NanoViewControllerBehaviorTests: XCTestCase {
    func test_withoutVM_hostsStaticContentViewAndUsesNoOpViewModel() {
        let scene = StaticScene()
        let sceneWithExplicitViewModel = StaticScene(viewModel: NanoViewControllerWithoutVMViewModel())

        scene.loadViewIfNeeded()
        sceneWithExplicitViewModel.loadViewIfNeeded()

        let wrapper = try? XCTUnwrap(
            scene.view.subviews.compactMap { $0 as? NanoViewControllerWithoutVMContentView<StaticContentView> }.first
        )
        let explicitWrapper = try? XCTUnwrap(
            sceneWithExplicitViewModel.view.subviews
                .compactMap { $0 as? NanoViewControllerWithoutVMContentView<StaticContentView> }
                .first
        )
        XCTAssertNotNil(wrapper?.contentView)
        XCTAssertNotNil(explicitWrapper?.contentView)
        XCTAssertTrue(wrapper?.contentView.superview === wrapper)
        XCTAssertEqual(wrapper?.contentView.translatesAutoresizingMaskIntoConstraints, false)

        let viewModel = NanoViewControllerWithoutVMViewModel()
        let input = NanoViewControllerWithoutVMViewModel.Input(
            fromView: NanoViewControllerWithoutVMViewModel.InputFromView(),
            fromController: makeEmptyInputFromController()
        )
        let output = viewModel.transform(input: input)

        XCTAssertTrue(output.cancellables.isEmpty)
    }

    func test_controllerLifecycleWriteBacksAndNavigationAreWired() {
        WiringContentView.populatedValues = []
        let viewModel = WiringViewModel()
        let scene = WiringScene(viewModel: viewModel)
        var navigationSteps = [WiringStep]()
        let navigation = scene.navigation.sink { navigationSteps.append($0) }

        scene.loadViewIfNeeded()
        pumpMainRunLoop()
        scene.beginAppearanceTransition(true, animated: false)
        scene.endAppearanceTransition()
        scene.leftBarButtonAbstractTarget.pressed()
        scene.rightBarButtonAbstractTarget.pressed()
        pumpMainRunLoop()

        XCTAssertEqual(viewModel.events, [.viewDidLoad, .viewWillAppear, .viewDidAppear, .leftButton, .rightButton])
        XCTAssertEqual(WiringContentView.populatedValues, ["published"])
        XCTAssertEqual(scene.title, "Loaded")
        XCTAssertNotNil(scene.navigationItem.leftBarButtonItem)
        XCTAssertNotNil(scene.navigationItem.rightBarButtonItem)
        XCTAssertEqual((scene.presentedToast as? UIAlertController)?.message, "Loaded toast")
        XCTAssertEqual(navigationSteps, [.rightButton])
        _ = navigation
    }

    func test_emptyTitleDoesNotOverwriteExistingTitleAndDescriptionUsesConcreteType() {
        let scene = EmptyTitleScene(viewModel: WiringViewModel())
        scene.title = "Existing"

        scene.loadViewIfNeeded()

        XCTAssertEqual(scene.title, "Existing")
        XCTAssertEqual(scene.description, "EmptyTitleScene")
    }

    func test_layoutApplicationHandlesNoNavigationControllerNewSameAndChangedLayout() {
        let standalone = LayoutWiringScene(viewModel: WiringViewModel())
        standalone.beginAppearanceTransition(true, animated: false)
        standalone.endAppearanceTransition()

        let scene = LayoutWiringScene(viewModel: WiringViewModel())
        let nav = NavigationBarLayoutingNavigationController(rootViewController: scene)

        nav.lastLayout = nil
        scene.beginAppearanceTransition(true, animated: false)
        scene.endAppearanceTransition()
        XCTAssertEqual(nav.lastLayout, LayoutWiringScene.config.navigationBarLayout)

        scene.beginAppearanceTransition(true, animated: false)
        scene.endAppearanceTransition()
        XCTAssertEqual(nav.lastLayout, LayoutWiringScene.config.navigationBarLayout)

        nav.lastLayout = .behaviorTest(visibility: .hidden(animated: false))
        scene.beginAppearanceTransition(true, animated: false)
        scene.endAppearanceTransition()
        XCTAssertEqual(nav.lastLayout, LayoutWiringScene.config.navigationBarLayout)
    }
}

private final class StaticContentView: UIView, EmptyInitializable {
    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }
}

private final class StaticScene: NanoViewControllerWithoutVM<StaticContentView> {}

private enum WiringStep: Sendable {
    case rightButton
}

private enum WiringEvent: Equatable {
    case viewDidLoad
    case viewWillAppear
    case viewDidAppear
    case leftButton
    case rightButton
}

private struct WiringInputFromView {}

private struct WiringPublishers {
    let value: AnyPublisher<String, Never>
}

private final class WiringViewModel: AbstractViewModel<WiringInputFromView, WiringPublishers, WiringStep> {
    private(set) var events = [WiringEvent]()

    override func transform(input: Input) -> Output<WiringPublishers, WiringStep> {
        let navigator = Navigator<WiringStep>()

        return Output(
            publishers: WiringPublishers(value: Just("published").eraseToAnyPublisher()),
            navigation: navigator.navigation
        ) {
            input.fromController.viewDidLoad
                .sink { [weak self] in
                    self?.events.append(.viewDidLoad)
                    input.fromController.titleSubject.send("Loaded")
                    input.fromController.leftBarButtonContentSubject.send(BarButtonContent(title: "Left"))
                    input.fromController.rightBarButtonContentSubject.send(BarButtonContent(system: .done))
                    input.fromController.toastSubject.send(Toast("Loaded toast", dismissing: .manual(dismissButtonTitle: "OK")))
                }

            input.fromController.viewWillAppear
                .sink { [weak self] in self?.events.append(.viewWillAppear) }

            input.fromController.viewDidAppear
                .sink { [weak self] in self?.events.append(.viewDidAppear) }

            input.fromController.leftBarButtonTrigger
                .sink { [weak self] in self?.events.append(.leftButton) }

            input.fromController.rightBarButtonTrigger
                .sink { [weak self, navigator] in
                    self?.events.append(.rightButton)
                    navigator.next(.rightButton)
                }
        }
    }
}

private final class WiringContentView: UIView, ViewModelled {
    typealias ViewModel = WiringViewModel

    static var populatedValues = [String]()

    var inputFromView: WiringInputFromView {
        WiringInputFromView()
    }

    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }

    func populate(with publishers: WiringPublishers) -> [AnyCancellable] {
        [
            publishers.value.sink { Self.populatedValues.append($0) },
        ]
    }
}

private final class WiringScene: NanoViewController<WiringContentView>, ControllerConfigProviding {
    static let config = ControllerConfig(
        leftBarButton: BarButtonContent(system: .cancel),
        rightBarButton: BarButtonContent(system: .done)
    )

    private(set) var presentedToast: UIViewController?

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated _: Bool,
        completion: (() -> Void)? = nil
    ) {
        presentedToast = viewControllerToPresent
        completion?()
    }
}

private final class EmptyTitleScene: NanoViewController<WiringContentView>, ControllerConfigProviding {
    static let config = ControllerConfig(title: "")
}

private final class LayoutWiringScene: NanoViewController<WiringContentView>, ControllerConfigProviding {
    static let config = ControllerConfig(navigationBarLayout: .behaviorTest(visibility: .visible(animated: false)))
}

private extension NavigationBarLayout {
    static func behaviorTest(visibility: Visibility) -> NavigationBarLayout {
        NavigationBarLayout(
            barStyle: .default,
            visibility: visibility,
            isTranslucent: false,
            barTintColor: .black,
            tintColor: .white,
            backgroundColor: .black,
            backgroundImage: UIImage(),
            shadowImage: UIImage(),
            titleFont: .systemFont(ofSize: 17),
            titleColor: .white
        )
    }
}

private func makeEmptyInputFromController() -> InputFromController {
    InputFromController(
        viewDidLoad: Empty().eraseToAnyPublisher(),
        viewWillAppear: Empty().eraseToAnyPublisher(),
        viewDidAppear: Empty().eraseToAnyPublisher(),
        leftBarButtonTrigger: Empty().eraseToAnyPublisher(),
        rightBarButtonTrigger: Empty().eraseToAnyPublisher(),
        titleSubject: .init(),
        leftBarButtonContentSubject: .init(),
        rightBarButtonContentSubject: .init(),
        toastSubject: .init()
    )
}
