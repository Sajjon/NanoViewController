// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import UIKit

/// Conformance signals that a `UIViewController` (typically a
/// ``SceneController``) wants its hosting navigation bar styled according to
/// a particular ``NavigationBarLayout``.
///
/// ``NavigationBarLayoutingNavigationController/viewWillAppear(_:)`` checks
/// for this conformance and pushes the layout onto its `navigationBar` — so
/// per-screen styling (e.g. translucent vs opaque, hidden bar) lives on the
/// controller instance instead of in shared appearance proxies.
///
/// ## Example
///
/// ```swift
/// final class WelcomeScene: Scene<WelcomeView>, NavigationBarLayoutOwner {
///     static var title: String { "" }
///
///     // Hide the nav bar entirely on the welcome screen.
///     var navigationBarLayout: NavigationBarLayout {
///         NavigationBarLayout(
///             barStyle:        .default,
///             visibility:      .hidden(animated: false),
///             isTranslucent:   true,
///             barTintColor:    .clear,
///             tintColor:       .label,
///             backgroundColor: .clear,
///             backgroundImage: UIImage(),
///             shadowImage:     UIImage(),
///             titleFont:       .preferredFont(forTextStyle: .headline),
///             titleColor:      .label
///         )
///     }
/// }
/// ```
@MainActor
public protocol NavigationBarLayoutOwner {
    /// The styling the controller wants applied while it's on screen.
    var navigationBarLayout: NavigationBarLayout { get }
}

public extension UINavigationBar {
    /// Mutates this navigation bar to match `layout`.
    ///
    /// Used by ``NavigationBarLayoutingNavigationController`` during
    /// view-will-appear so each scene can stamp its own bar styling. Stamps
    /// the resulting `UINavigationBarAppearance` into all four metrics
    /// (standard, scroll-edge, compact, compact-scroll-edge) so the bar looks
    /// consistent across orientation/scroll states.
    ///
    /// Returns the same `layout` to make chaining easy at call sites that
    /// want to remember what they applied.
    ///
    /// - Parameter layout: The styling to apply.
    /// - Returns: The `layout` argument unchanged.
    @discardableResult
    func applyLayout(_ layout: NavigationBarLayout) -> NavigationBarLayout {
        barStyle = layout.barStyle
        isTranslucent = layout.isTranslucent
        tintColor = layout.tintColor

        let navBarAppearance = UINavigationBarAppearance()
        // iOS 13+ requires us to choose between transparent and opaque
        // background configurations explicitly — the legacy
        // `setBackgroundImage` API is deprecated.
        if layout.isTranslucent, layout.backgroundColor == .clear {
            navBarAppearance.configureWithTransparentBackground()
        } else {
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = layout.barTintColor
        }
        navBarAppearance.titleTextAttributes = layout.titleTextAttributes
        navBarAppearance.shadowColor = .clear

        // Stamp the appearance into all four metrics so the bar looks
        // consistent in both portrait and landscape, both standard and
        // scroll-edge states (matters on iPad and iOS 15+).
        standardAppearance = navBarAppearance
        scrollEdgeAppearance = navBarAppearance
        compactAppearance = navBarAppearance
        compactScrollEdgeAppearance = navBarAppearance

        return layout
    }
}

/// Per-screen navigation-bar styling.
///
/// Applied in the `UINavigationBar.applyLayout(_:)` extension above and produced via
/// consumer factories — the package ships no brand-default values, leaving
/// it to consumers (Zhip, the SignUpDemo example) to declare static factories
/// like `.opaque` / `.translucent(...)` / `.hidden` on top.
///
/// All fields are required at construction so a brand factory can't
/// accidentally forget to set one.
///
/// ## Example — declaring brand factories on top of the struct
///
/// ```swift
/// extension NavigationBarLayout {
///     static func opaque(brand: BrandPalette) -> NavigationBarLayout {
///         NavigationBarLayout(
///             barStyle:        .default,
///             visibility:      .visible(animated: false),
///             isTranslucent:   false,
///             barTintColor:    brand.surface,
///             tintColor:       brand.accent,
///             backgroundColor: brand.surface,
///             backgroundImage: UIImage(),
///             shadowImage:     UIImage(),
///             titleFont:       brand.headlineFont,
///             titleColor:      brand.onSurface
///         )
///     }
///
///     static var hidden: NavigationBarLayout {
///         NavigationBarLayout(
///             barStyle:      .default,
///             visibility:    .hidden(animated: false),
///             isTranslucent: true,
///             barTintColor:    .clear, tintColor: .label,
///             backgroundColor: .clear, backgroundImage: UIImage(), shadowImage: UIImage(),
///             titleFont: .systemFont(ofSize: 17), titleColor: .label
///         )
///     }
/// }
///
/// // Consumer screen:
/// final class HomeScene: Scene<HomeView>, NavigationBarLayoutOwner {
///     var navigationBarLayout: NavigationBarLayout { .opaque(brand: .primary) }
/// }
/// ```
public struct NavigationBarLayout: Equatable, Sendable {
    /// Field-by-field equality (`UIImage` and dictionary equality are not
    /// auto-synthesized — Swift can't compare `UIImage` for value equality).
    public static func == (lhs: NavigationBarLayout, rhs: NavigationBarLayout) -> Bool {
        lhs.visibility == rhs.visibility &&
            lhs.isTranslucent == rhs.isTranslucent &&
            lhs.tintColor == rhs.tintColor &&
            lhs.barTintColor == rhs.barTintColor &&
            lhs.backgroundColor == rhs.backgroundColor &&
            lhs.backgroundImage == rhs.backgroundImage &&
            lhs.shadowImage == rhs.shadowImage &&
            lhs.titleFont == rhs.titleFont &&
            lhs.titleColor == rhs.titleColor
    }

    /// Light vs dark bar style — controls the status bar foreground colour.
    public let barStyle: UIBarStyle

    /// Whether the bar is hidden or visible (and whether the transition animates).
    public let visibility: Visibility

    /// Whether the bar background is translucent (allows content to bleed
    /// through).
    public let isTranslucent: Bool

    /// Tint applied to bar-button items and back chevron.
    public let tintColor: UIColor

    /// Bar background colour in opaque mode.
    public let barTintColor: UIColor

    /// Background colour (only honored when `isTranslucent == true`).
    public let backgroundColor: UIColor

    /// Background image (use empty `UIImage()` to clear).
    public let backgroundImage: UIImage

    /// 1pt shadow image under the bar (use empty `UIImage()` to clear).
    public let shadowImage: UIImage

    /// Title text font.
    public let titleFont: UIFont

    /// Title text colour.
    public let titleColor: UIColor

    /// Convenience: the flattened `[font, color]` form expected by
    /// `UINavigationBarAppearance.titleTextAttributes`.
    public var titleTextAttributes: [NSAttributedString.Key: Any] {
        [.font: titleFont, .foregroundColor: titleColor]
    }

    /// Memberwise init.
    ///
    /// Every field is required — consumers layer their own brand-default
    /// factories on top of this struct.
    public init(
        barStyle: UIBarStyle,
        visibility: Visibility,
        isTranslucent: Bool,
        barTintColor: UIColor,
        tintColor: UIColor,
        backgroundColor: UIColor,
        backgroundImage: UIImage,
        shadowImage: UIImage,
        titleFont: UIFont,
        titleColor: UIColor
    ) {
        self.barStyle = barStyle
        self.visibility = visibility
        self.isTranslucent = isTranslucent
        self.barTintColor = barTintColor
        self.tintColor = tintColor
        self.backgroundColor = backgroundColor
        self.backgroundImage = backgroundImage
        self.shadowImage = shadowImage
        self.titleFont = titleFont
        self.titleColor = titleColor
    }
}

public extension NavigationBarLayout {
    /// Whether the navigation bar is visible, plus whether the visibility
    /// transition itself should be animated.
    enum Visibility: Equatable, Sendable {
        /// Bar should be hidden; `animated` controls the show/hide transition.
        case hidden(animated: Bool)
        /// Bar should be visible; `animated` controls the show/hide transition.
        case visible(animated: Bool)

        /// `true` for the `.hidden` case, `false` otherwise.
        public var isHidden: Bool {
            switch self {
            case .hidden: true
            default: false
            }
        }

        /// Whether the show/hide transition should animate.
        public var animated: Bool {
            switch self {
            case let .hidden(animated): animated
            case let .visible(animated): animated
            }
        }
    }
}
