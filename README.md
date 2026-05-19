[![codecov](https://codecov.io/gh/Sajjon/NanoViewController/graph/badge.svg?token=vocbUWuuwq)](https://codecov.io/gh/Sajjon/NanoViewController)

# NVC: NanoViewController
An **extremely** opinionated UIKit architecture built on top of MVVM-C allowing you to create `UIViewController`s declaratively with as little as a single line of code.

## Show me code

A quick inline taste of the architecture — for a runnable toy example and a real-world app see [Showcase](#showcase).

```swift
// MARK: NanoViewController
public final class SignUpScene: NanoViewController<SignUpView>, ControllerConfigProviding { // tiny VC
    public static let config = ControllerConfig(title: "Sign Up")
}

// MARK: View
public final class SignUpView: UIView {
	private lazy var nameField: 	UITextField 			= { ... }()
	private lazy var emailField: 	UITextField 			= { ... }()
	private lazy var submitButton: 	UIButton 				= { ... }()
	private lazy var spinner: 		UIActivityIndicatorView = { ... }()
}
extension SignUpView: ViewModelled {
    public typealias ViewModel = SignUpViewModel

    public var inputFromView: InputFromView {
        InputFromView(
            name: nameField.textPublisher.orEmpty,
            email: emailField.textPublisher.orEmpty,
            submitTrigger: submitButton.tapPublisher
        )
    }

    public func populate(with publishers: ViewModel.Publishers) -> [AnyCancellable] {
        publishers.isSubmitEnabled 	--> submitButton.isEnabledBinder
        publishers.loadingText 		--> submitButton.titleBinder(for: .normal)
        publishers.isLoading 		--> spinner.isAnimatingBinder
    }
}

// MARK: ViewModel.InputFromView
public extension SignUpViewModel {
	struct InputFromView {
		public let name: AnyPublisher<String, Never>
		public let email: AnyPublisher<String, Never>
		public let submitTrigger: AnyPublisher<Void, Never>
	}
}

// MARK: ViewModel.Publishers
public extension SignUpViewModel {
	struct Publishers {
		public let isSubmitEnabled: AnyPublisher<Bool, Never>
		public let isLoading: AnyPublisher<Bool, Never>
	}
}

// MARK: SignUpViewModel
public final class SignUpViewModel: AbstractViewModel<
    SignUpViewModel.InputFromView,
    SignUpViewModel.Publishers,
    SignUpUserAction // NavigationStep
> {
	private let service: SignUpServicing

	// MARK: AbstractViewModel Overrides
    override public func transform(input: Input) -> Output<Publishers, SignUpUserAction> {
        let navigator = Navigator<SignUpUserAction>()
        let activity  = ActivityIndicator()

        // Name + email both non-empty → form is valid.
        let isFormValid: AnyPublisher<Bool, Never> = input.fromView.name
            .combineLatest(input.fromView.email)
            .map { name, email in
                !name.trimmingCharacters(in: .whitespaces).isEmpty
                    && !email.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .eraseToAnyPublisher()

        let isLoading = activity.asPublisher()

        // Submit is enabled only when the form is valid AND we're not already
        // mid-request (prevents double-taps from firing two sign-ups).
        let isSubmitEnabled = isFormValid
            .combineLatest(isLoading)
            .map { valid, loading in valid && !loading }
            .eraseToAnyPublisher()

        return Output(
            publishers: Publishers(
                isSubmitEnabled: isSubmitEnabled,
                isLoading: isLoading
            ),
            navigation: navigator.navigation
        ) {
            // On submit-tap: snapshot the latest (name, email), call the service
            // (tracking activity), forward the resulting user as `.signedUp`.
            input.fromView.submitTrigger
                .withLatestFrom(input.fromView.name.combineLatest(input.fromView.email))
                .map { [service] name, email in
                    service.signUp(name: name, email: email)
                        .trackActivity(activity)
                }
                .switchToLatest()
                .sink { [navigator] user in
                    navigator.next(.signedUp(user))
                }
        }
    }
}

// MARK: NavigationStep
public enum SignUpUserAction: Sendable {
    case signedUp(SignedUpUser)
}
```

# Library products
The package ships six independent SPM library targets so consumers can pick exactly what they need:

| Product | Layer | Notes |
|---|---|---|
| `NanoViewControllerCore` | value types | `Output`, `EmptyInitializable`, `AbstractTarget`, `ActivityIndicator`, `ErrorTracker`, `BindingsBuilder` |
| `NanoViewControllerCombine` | reactive | `Binder`, the `-->` operator, `Publisher+Extras`, `UIControl`/`UITextField`/`UIView` publisher extensions |
| `NanoViewControllerNavigation` | coordinators | `Coordinating`, `BaseCoordinator`, `Navigator`, `Stepper` |
| `NanoViewControllerController` | UIKit glue | `NanoViewController<View>`, `AbstractViewModel`, `ViewModelType`, `InputType`, `ControllerConfig`, `BarButtonContent`, `InputFromController`, `ViewModelled`, `NavigationBarLayoutingNavigationController`, `Toast` |
| `NanoViewControllerSceneViews` | UIKit views | `AbstractSceneView`, `BaseScrollableStackViewOwner`, `BaseTableViewOwner`, `SingleCellTypeTableView`, `CellConfigurable`, pull-to-refresh / class-identifiable / footer plumbing |
| `NanoViewControllerDIPrimitives` | DI protocols | `Clock`, `MainScheduler`, `DateProvider`, `HapticFeedback`, `Pasteboard`, `UrlOpener` |

`Combine`, `Navigation`, `Controller`, `SceneViews`, `DIPrimitives` all depend on `Core`. UIKit modules (`Controller`, `SceneViews`, `DIPrimitives`) need iOS 26+; pure value-type modules build on macOS 14+ too. Every target compiles in Swift 6.2 language mode (`swift-tools-version: 6.2`) so the package's `@MainActor`-on-UIKit annotations are enforced as hard errors at the consumer's call site.

# Testing your coordinators

Coordinators in NVC register routing logic as a trailing closure to `push(...)` / `modallyPresent(...)`:

```swift
push(scene: PrepareScene.self, viewModel: vm) { [weak self] step in
    guard let self else { return }
    switch step {
    case .cancel:                finish()
    case let .submit(payment):   toReviewPayment(payment)
    }
}
```

That closure is invoked through a Combine subscription on the scene's `navigation` publisher — driving it from a unit test would normally mean taking the long way around: a ViewModel-level test that drives the view's input subjects through real UIKit (`tap`, `setText`, `drainRunLoop`) so the ViewModel's `transform` finally emits the step, the subscription fires, and the closure runs.

NVC exposes the closure directly on each `NanoViewController` instance under an `@_spi(Testing)` seam so unit tests can short-circuit the pipeline:

```swift
@_spi(Testing) import NanoViewControllerController

func test_submitPayment_pushesReviewTransaction() throws {
    // Arrange
    let coordinator = SendCoordinator(navigationController: nav, deeplinks: Empty().eraseToAnyPublisher())
    coordinator.start()
    let prepare = try XCTUnwrap(nav.viewControllers.first as? PrepareScene)

    // Act
    prepare.navigationHandler?(.submit(payment))

    // Assert
    XCTAssertTrue(nav.viewControllers.last is ReviewScene)
}
```

Two hooks ship on every `NanoViewController<View>`:

| Hook | Set by | Closure shape |
|---|---|---|
| `scene.navigationHandler`      | `push(...)` / `pushSceneInstance(...)`              | `(NavigationStep) -> Void`                  |
| `scene.modalNavigationHandler` | `modallyPresent(...)` / `replaceAllScenes(...)`     | `(NavigationStep, DismissScene) -> Void`    |

The modal variant accepts a spy `DismissScene` so tests can observe both the routing and the dismissal:

```swift
var dismissCalled = false
let spy: DismissScene = { _, completion in
    dismissCalled = true
    completion?()
}
scan.modalNavigationHandler?(.scanned(intent), spy)
XCTAssertTrue(dismissCalled)
```

**Trade-off.** Driving the SPI handler directly does not assert that the ViewModel's emitted step actually reaches the coordinator's subscription — only that the handler routes correctly once invoked. The Combine wiring is identical across every `push(...)` / `modallyPresent(...)` call, so a single happy-path UI-driven test (or simply observing that the scene appears on the stack after `start()`) is enough to cover it. Use the SPI for the per-step routing assertions; rely on ViewModel-level tests for the emission contracts.

**Visibility.** The two hooks are `@_spi(Testing) public internal(set)` — production callers don't see them unless they opt in with `@_spi(Testing) import NanoViewControllerController`. Only NVC writes through them; consumers can only read.

# Local development

First-time setup on a fresh clone:

```sh
brew install just     # bootstraps the rest
just bootstrap        # brew bundle install + git hooks (pre-commit + pre-push)
```

Then:

```sh
just test       # build + run the per-package XCTest bundles on iPhone 17 / iOS 26.1
just cov        # tests with coverage report
just fmt        # swiftformat + swiftlint --fix
just            # list every recipe
```

CI runs the same pipeline on every push / PR — typos check, swiftformat lint, swiftlint strict, build + test on the iOS Simulator. See `.github/workflows/ci.yml`.

The `pre-commit` hook installed by `just bootstrap` enforces: typos, shellcheck, swiftformat lint, swiftlint strict on every commit; and the full test suite on every push.

# Showcase

## SignUpDemo (toy, in this repo)

[`Examples/SignUpDemo/`](./Examples/SignUpDemo/) is a small UIKit iOS app that walks through every load-bearing piece of the package: a `NanoViewController`-backed sign-up screen, a `Coordinator` swap on success, and a logout button on the home screen that re-runs the onboarding flow. It uses a stub `SignUpServicing` (instant-success) so it runs out of the box on the simulator.

```sh
just example-gen     # generate Examples/SignUpDemo/SignUpDemo.xcodeproj from project.yml
just example-build   # xcodebuild for iPhone 17 simulator
open Examples/SignUpDemo/SignUpDemo.xcodeproj   # then ⌘R in Xcode
```

The example shows the canonical wiring: controller = `NanoViewController<View>`, view-model subclasses the package's `AbstractViewModel<InputFromView, Publishers, NavigationStep>`, declares a local `Navigator<Step>` inside `transform` and surfaces it on the returned `Output<Publishers, Step>`. The coordinator subscribes to that publisher (via the hosting controller's `.navigation`) and routes the user-actions to push / pop / present transitions.

## Zhip (real-world iOS wallet)

[Zhip](https://github.com/Sajjon/Zhip) is a full-featured iOS wallet app built on the same architecture (originally with the predecessor "SLC: SingleLineController" — see [History](#history) below). A larger, real-world example of `NanoViewController` in production use.

# History
Implementation happened in 2018 in https://github.com/sajjon/zhip (originally https://github.com/openzesame/zhip); then called "SLC: SingleLineController". You can read my blog posts from 2018, [part one](https://medium.com/@sajjon/single-line-controller-fbe474857787) and [part two](https://medium.com/@sajjon/single-line-controller-advanced-case-406e76731ee6) - since ported from RxSwift to Combine and extracted into this separate repo.
