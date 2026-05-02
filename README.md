# NVC: NanoViewController
A UIKit architecture built on top of MVVM-C allowing you to create `UIViewController`s declaratively with as little as a single line of code.

# History
Implementation happened in 2018 in https://github.com/sajjon/zhip (originally https://github.com/openzesame/zhip); then called "SLC: SingleLineController". You can read my blog posts from 2018, [part one](https://medium.com/@sajjon/single-line-controller-fbe474857787) and [part two](https://medium.com/@sajjon/single-line-controller-advanced-case-406e76731ee6) - since ported from RxSwift to Combine and extracted into this separate repo.

# Library products
The package ships six independent SPM library targets so consumers can pick exactly what they need:

| Product | Layer | Notes |
|---|---|---|
| `NanoViewControllerCore` | value types | `ViewModelType`, `InputType`, `EmptyInitializable`, `AbstractViewModel`, `AbstractTarget`, `ActivityIndicator`, `ErrorTracker` |
| `NanoViewControllerCombine` | reactive | `Binder`, the `-->` operator, `Publisher+Extras`, `UIControl`/`UITextField`/`UIView` publisher extensions |
| `NanoViewControllerNavigation` | coordinators | `Coordinating`, `BaseCoordinator`, `Navigator`, `Stepper` |
| `NanoViewControllerController` | UIKit glue | `SceneController<View>`, `BarButtonContent`, `InputFromController`, `ViewModelled`, `NavigationBarLayoutingNavigationController`, `Toast` |
| `NanoViewControllerSceneViews` | UIKit views | `AbstractSceneView`, `BaseScrollableStackViewOwner`, `BaseTableViewOwner`, `SingleCellTypeTableView`, `CellConfigurable`, pull-to-refresh / class-identifiable / footer plumbing |
| `NanoViewControllerDIPrimitives` | DI protocols | `Clock`, `MainScheduler`, `DateProvider`, `HapticFeedback`, `Pasteboard`, `UrlOpener` |

`Combine`, `Navigation`, `Controller`, `SceneViews`, `DIPrimitives` all depend on `Core`. UIKit modules (`Controller`, `SceneViews`, `DIPrimitives`) need iOS 17+; pure value-type modules build on macOS too.

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