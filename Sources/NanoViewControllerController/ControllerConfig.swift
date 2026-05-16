// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

/// Static controller chrome configuration for a ``NanoViewController``.
///
/// The default value is intentionally empty: no title, no static bar buttons,
/// no back-button override, and no navigation-bar layout override. Dynamic
/// bar-button changes still flow through ``InputFromController``.
public struct ControllerConfig: Sendable {
    public static let `default` = ControllerConfig()

    /// Navigation title installed during `viewDidLoad`. Empty and `nil` both
    /// mean "leave the title alone".
    public let title: String?

    /// Whether to hide the system back button and disable interactive pop.
    public let hidesBackButton: Bool

    /// Static left bar button installed during `viewDidLoad`.
    public let leftBarButton: BarButtonContent?

    /// Static right bar button installed during `viewDidLoad`.
    public let rightBarButton: BarButtonContent?

    /// Optional per-controller navigation-bar layout.
    public let navigationBarLayout: NavigationBarLayout?

    public init(
        title: String? = nil,
        hidesBackButton: Bool = false,
        leftBarButton: BarButtonContent? = nil,
        rightBarButton: BarButtonContent? = nil,
        navigationBarLayout: NavigationBarLayout? = nil
    ) {
        self.title = title
        self.hidesBackButton = hidesBackButton
        self.leftBarButton = leftBarButton
        self.rightBarButton = rightBarButton
        self.navigationBarLayout = navigationBarLayout
    }
}

/// Optional static configuration hook for `NanoViewController` subclasses.
///
/// Concrete final screens can use a `static let config` without overriding a
/// `class var`, which keeps the common declaration terse and SwiftLint-clean:
///
/// ```swift
/// final class LoginScene: NanoViewController<LoginView>, ControllerConfigProviding {
///     static let config = ControllerConfig(title: "Login")
/// }
/// ```
///
/// Screens whose chrome depends on construction-time state should instead
/// override ``NanoViewController/controllerConfig``.
@MainActor
public protocol ControllerConfigProviding {
    static var config: ControllerConfig { get }
}
