// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine

/// Abstraction the SignUp flow depends on. A real app would back this with
/// a network call; the demo wires up `DummySignUpService` (instant success).
///
/// Modeled as `AnyPublisher` so the ViewModel can compose it with the rest
/// of its Combine pipeline (track activity, swallow errors, etc.).
public protocol SignUpServicing {
    /// Returns a publisher that emits exactly one `SignedUpUser` and finishes.
    /// Failure type is `Never` here because the demo can't fail; a real impl
    /// would use a typed error.
    func signUp(name: String, email: String) -> AnyPublisher<SignedUpUser, Never>
}
