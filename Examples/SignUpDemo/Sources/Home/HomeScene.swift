// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import NanoViewControllerController

/// `NanoViewController` glue for the Home screen.
public final class HomeScene: NanoViewController<HomeView>, ControllerConfigProviding {
    public static let config = ControllerConfig(title: "Home")
}
