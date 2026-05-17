// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

@testable import NanoViewControllerController
import NanoViewControllerCore
import NanoViewControllerDIPrimitives
import UIKit
import XCTest

@MainActor
final class NavigationBarAndToastTests: XCTestCase {
    func test_barButtonContentCreatesTextImageAndSystemItems() {
        let target = ButtonTarget()
        let selector = #selector(ButtonTarget.action)
        let image = UIImage()

        let text = BarButtonContent(title: "Save", style: .prominent).makeBarButtonItem(target: target, selector: selector)
        let imageItem = BarButtonContent(image: image).makeBarButtonItem(target: target, selector: selector)
        let system = BarButtonContent(system: .cancel).makeBarButtonItem(target: target, selector: selector)

        XCTAssertEqual(text.title, "Save")
        XCTAssertEqual(text.style, .prominent)
        XCTAssertTrue(imageItem.image === image)
        XCTAssertNil(system.title)
    }

    func test_navigationBarLayoutVisibilityEqualityAndApplication() {
        let visible = NavigationBarLayout.test(visibility: .visible(animated: true), translucent: false)
        let hidden = NavigationBarLayout.test(visibility: .hidden(animated: false), translucent: true)
        let navBar = UINavigationBar()

        XCTAssertFalse(visible.visibility.isHidden)
        XCTAssertTrue(visible.visibility.animated)
        XCTAssertTrue(hidden.visibility.isHidden)
        XCTAssertFalse(hidden.visibility.animated)
        XCTAssertNotEqual(visible, hidden)

        XCTAssertEqual(navBar.applyLayout(visible), visible)
        XCTAssertEqual(navBar.barStyle, visible.barStyle)
        XCTAssertEqual(navBar.tintColor, visible.tintColor)
        XCTAssertEqual(navBar.standardAppearance.titleTextAttributes[.foregroundColor] as? UIColor, visible.titleColor)

        navBar.applyLayout(hidden)
        XCTAssertEqual(navBar.standardAppearance.backgroundColor, nil)
    }

    func test_navigationBarLayoutingNavigationControllerAppliesConfiguredLayouts() {
        let nav = NavigationBarLayoutingNavigationController()
        let first = LayoutViewController(layout: .test(visibility: .visible(animated: false)))
        let second = LayoutViewController(layout: .test(visibility: .hidden(animated: false)))

        nav.applyLayoutToViewController(nil)
        nav.applyLayoutToViewController(UIViewController())
        XCTAssertNil(nav.lastLayout)

        nav.pushViewController(first, animated: false)
        XCTAssertEqual(nav.lastLayout, first.controllerConfig.navigationBarLayout)
        XCTAssertFalse(nav.isNavigationBarHidden)

        nav.pushViewController(second, animated: false)
        XCTAssertEqual(nav.lastLayout, second.controllerConfig.navigationBarLayout)
        XCTAssertTrue(nav.isNavigationBarHidden)

        let third = LayoutViewController(layout: .test(visibility: .visible(animated: false)))
        nav.pushViewController(third, animated: false)
        XCTAssertEqual(nav.popToViewController(first, animated: false), [second, third])
        XCTAssertEqual(nav.lastLayout, first.controllerConfig.navigationBarLayout)

        nav.pushViewController(second, animated: false)
        nav.pushViewController(third, animated: false)
        XCTAssertEqual(nav.popToRootViewController(animated: false), [second, third])
        XCTAssertEqual(nav.lastLayout, first.controllerConfig.navigationBarLayout)

        let modal = LayoutViewController(layout: .test(visibility: .hidden(animated: false)))
        nav.present(modal, animated: false)
        XCTAssertEqual(nav.lastLayout, modal.controllerConfig.navigationBarLayout)

        nav.pushViewController(second, animated: false)
        XCTAssertTrue(nav.popViewController(animated: false) === second)
        XCTAssertEqual(nav.lastLayout, first.controllerConfig.navigationBarLayout)

        nav.beginAppearanceTransition(true, animated: false)
        nav.endAppearanceTransition()
        XCTAssertTrue(nav.gestureRecognizer(UIGestureRecognizer(), shouldRecognizeSimultaneouslyWith: UIGestureRecognizer()))
        XCTAssertTrue(nav.gestureRecognizer(UIGestureRecognizer(), shouldRequireFailureOf: UIScreenEdgePanGestureRecognizer()))
    }

    func test_toastPresentationManualAndAutomaticDismissPaths() {
        let host = PresentationCapturingViewController()
        let clock = ImmediateClock()
        var autoDismissed = false

        let literal: Toast = "Literal"
        literal.present(using: host, clock: clock)
        XCTAssertEqual((host.presentedViewControllerCapture as? UIAlertController)?.message, "Literal")

        Toast("Manual", dismissing: .manual(dismissButtonTitle: "OK")).present(using: host, clock: clock)
        let manualAlert = host.presentedViewControllerCapture as? UIAlertController
        XCTAssertEqual(manualAlert?.message, "Manual")
        XCTAssertEqual(manualAlert?.actions.first?.title, "OK")

        Toast("Automatic", dismissing: .after(duration: 1.5)).present(
            using: host,
            clock: clock,
            dismissedCompletion: { autoDismissed = true }
        )

        let automaticAlert = host.presentedViewControllerCapture as? UIAlertController
        XCTAssertEqual(automaticAlert?.message, "Automatic")
        XCTAssertEqual(clock.delays, [0.6, 1.5])
        XCTAssertTrue(autoDismissed)
    }
}

private final class ButtonTarget: NSObject {
    @objc func action() {}
}

private final class LayoutViewController: UIViewController, ControllerConfigReadable {
    let controllerConfig: ControllerConfig

    init(layout: NavigationBarLayout) {
        self.controllerConfig = ControllerConfig(navigationBarLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }
}

private final class PresentationCapturingViewController: UIViewController {
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

private final class ImmediateClock: Clock {
    private(set) var delays = [TimeInterval]()

    func schedule(after delay: TimeInterval, execute block: @escaping () -> Void) -> Task<Void, Never> {
        delays.append(delay)
        block()
        return Task {}
    }
}

private extension NavigationBarLayout {
    static func test(
        visibility: Visibility,
        translucent: Bool = false
    ) -> NavigationBarLayout {
        NavigationBarLayout(
            barStyle: .black,
            visibility: visibility,
            isTranslucent: translucent,
            barTintColor: .black,
            tintColor: .red,
            backgroundColor: translucent ? .clear : .black,
            backgroundImage: UIImage(),
            shadowImage: UIImage(),
            titleFont: .boldSystemFont(ofSize: 17),
            titleColor: .blue
        )
    }
}
