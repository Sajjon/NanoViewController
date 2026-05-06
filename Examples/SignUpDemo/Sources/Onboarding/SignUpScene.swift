// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import NanoViewControllerController

/// `SceneController` glue for the SignUp screen. The empty body is intentional:
/// `SceneController<SignUpView>` already wires the View ↔ ViewModel pipeline;
/// `TitledScene` bolts on the navigation-bar title.
public final class SignUpScene: Scene<SignUpView> {
    public static let title = "Sign Up"
}
