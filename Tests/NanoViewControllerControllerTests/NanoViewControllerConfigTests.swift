// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerController
import NanoViewControllerCore
import UIKit
import XCTest

@MainActor
final class NanoViewControllerConfigTests: XCTestCase {
    func test_controllerConfig_localizedTitleInitializer_resolvesTitleKey() {
        let config = ControllerConfig(
            titleKey: "Localized Configured",
            hidesBackButton: true,
            leftBarButton: BarButtonContent(system: .cancel),
            rightBarButton: BarButtonContent(system: .done),
            navigationBarLayout: .testHidden
        )

        XCTAssertEqual(config.title, "Localized Configured")
        XCTAssertTrue(config.hidesBackButton)
        XCTAssertEqual(config.leftBarButton?.systemItem, .cancel)
        XCTAssertEqual(config.rightBarButton?.systemItem, .done)
        XCTAssertEqual(config.navigationBarLayout?.visibility, .hidden(animated: false))
    }

    func test_viewDidLoad_appliesStaticControllerConfig() {
        let scene = ConfiguredScene(viewModel: ConfiguredViewModel())

        scene.loadViewIfNeeded()

        XCTAssertEqual(scene.title, "Configured")
        XCTAssertTrue(scene.navigationItem.hidesBackButton)
        XCTAssertNotNil(scene.navigationItem.leftBarButtonItem)
        XCTAssertNotNil(scene.navigationItem.rightBarButtonItem)
    }

    func test_navigationController_appliesLayoutFromControllerConfig() {
        let scene = ConfiguredScene(viewModel: ConfiguredViewModel())
        let nav = NavigationBarLayoutingNavigationController()

        nav.pushViewController(scene, animated: false)

        XCTAssertEqual(nav.lastLayout?.visibility, .hidden(animated: false))
    }

    func test_navigationController_appliesInstanceControllerConfig() {
        let scene = DynamicConfiguredScene(
            viewModel: ConfiguredViewModel(),
            layout: .testVisible
        )
        let nav = NavigationBarLayoutingNavigationController()

        nav.pushViewController(scene, animated: false)

        XCTAssertEqual(nav.lastLayout?.visibility, .visible(animated: false))
    }
}

private final class ConfiguredViewModel: AbstractViewModel<ConfiguredInputFromView, ConfiguredPublishers, Never> {
    override func transform(input _: Input) -> Output<ConfiguredPublishers, Never> {
        Output(publishers: ConfiguredPublishers())
    }
}

private struct ConfiguredInputFromView {}
private struct ConfiguredPublishers {}

private final class ConfiguredView: UIView, ViewModelled {
    typealias ViewModel = ConfiguredViewModel

    var inputFromView: ConfiguredInputFromView {
        ConfiguredInputFromView()
    }

    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }
}

private final class ConfiguredScene: NanoViewController<ConfiguredView>, ControllerConfigProviding {
    static let config = ControllerConfig(
        title: "Configured",
        hidesBackButton: true,
        leftBarButton: BarButtonContent(system: .cancel),
        rightBarButton: BarButtonContent(system: .done),
        navigationBarLayout: .testHidden
    )
}

private final class DynamicConfiguredScene: NanoViewController<ConfiguredView> {
    private let layout: NavigationBarLayout

    override var controllerConfig: ControllerConfig {
        ControllerConfig(navigationBarLayout: layout)
    }

    init(viewModel: ConfiguredViewModel, layout: NavigationBarLayout) {
        self.layout = layout
        super.init(viewModel: viewModel)
    }

    required init(viewModel: ConfiguredViewModel) {
        self.layout = .testVisible
        super.init(viewModel: viewModel)
    }
}

private extension NavigationBarLayout {
    static var testHidden: NavigationBarLayout {
        test(visibility: .hidden(animated: false))
    }

    static var testVisible: NavigationBarLayout {
        test(visibility: .visible(animated: false))
    }

    static func test(visibility: Visibility) -> NavigationBarLayout {
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

private extension BarButtonContent {
    var systemItem: UIBarButtonItem.SystemItem? {
        guard case let .system(systemItem) = type else {
            return nil
        }
        return systemItem
    }
}
