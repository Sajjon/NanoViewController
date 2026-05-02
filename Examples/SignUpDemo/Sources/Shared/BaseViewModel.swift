// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerController
import NanoViewControllerCore
import NanoViewControllerNavigation

/// Local convenience over `AbstractViewModel` that fixes `FromController` to the
/// package's standard `InputFromController` and adds a typed `Navigator<Step>`.
///
/// Lives in the example (not in NanoViewController itself) on purpose: the
/// package ships `AbstractViewModel<FromView, FromController, Output>` so you
/// can swap in any controller-input shape you like. Most apps will end up with
/// a tiny base class like this one of their own.
open class BaseViewModel<NavigationStep, InputFromView, Output>:
    AbstractViewModel<InputFromView, InputFromController, Output>,
    Navigating
{
    /// Stepper the coordinator subscribes to. Subclasses call `navigator.next(.step)`
    /// to declare an intent; the coordinator decides how to satisfy it.
    public let navigator = Navigator<NavigationStep>()
}
