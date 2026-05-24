// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
import Foundation

/// Stub implementation of `SignUpServicing` for the demo. Pretends to talk to
/// a server by waiting half a second on the main runloop, then echoes the
/// inputs back as a freshly-minted `SignedUpUser`.
///
/// The 0.5s delay is intentional — it lets the SignUp button's spinner appear
/// long enough to see, demonstrating the activity-tracking pattern in the
/// SignUpViewModel.
public struct DummySignUpService: SignUpServicing {
    public init() {}

    public func signUp(name: String, email: String) -> AnyPublisher<SignedUpUser, Never> {
        Just(SignedUpUser(id: UUID(), name: name, email: email))
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
