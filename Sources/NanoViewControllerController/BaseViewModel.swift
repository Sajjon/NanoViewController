// MIT License — Copyright (c) 2018-2026 Open Zesame

import NanoViewControllerCore
import NanoViewControllerNavigation

/// Concrete convenience over `AbstractViewModel` that pins `FromController` to
/// the package's standard `InputFromController` and adds a typed
/// `Navigator<Step>`. This is the base class most concrete view models in
/// consuming apps should subclass.
///
/// Generic parameters:
/// - `NavigationStep` — the per-scene navigation enum the coordinator
///   listens for (e.g. `enum SignUpUserAction { case signedUp(User) }`).
/// - `InputFromView` — the view-event channel struct nested inside the
///   subclass (taps, text changes, toggles).
/// - `Output` — the bag of publishers the view binds to UI controls.
///
/// `AbstractViewModel` stays generic over `FromController` so consumers who
/// want a different controller-input shape can still use it directly. Use this
/// class otherwise — it's what 99% of scenes need.
open class BaseViewModel<NavigationStep, InputFromView, Output>:
    AbstractViewModel<InputFromView, InputFromController, Output>,
    Navigating
{
    /// Stepper the coordinator subscribes to. Subclasses call `navigator.next(.step)`
    /// to declare an intent; the coordinator decides how to satisfy it
    /// (push, pop, present, finish).
    public let navigator = Navigator<NavigationStep>()
}
