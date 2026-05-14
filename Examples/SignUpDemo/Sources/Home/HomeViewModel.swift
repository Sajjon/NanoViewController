// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerController
import NanoViewControllerCore

/// User outcomes the Home scene can emit.
public enum HomeUserAction: Sendable {
    case logout
}

/// Drives `HomeView`: produces a static "Welcome, <name>" greeting + forwards
/// the logout-button tap to the coordinator.
public final class HomeViewModel: BaseViewModel<
    HomeUserAction,
    HomeViewModel.InputFromView,
    HomeViewModel.Output
> {
    private let user: SignedUpUser

    public init(user: SignedUpUser) {
        self.user = user
        super.init()
    }

    override public func transform(input: Input) -> Output {
        input.fromView.logoutTrigger
            .sink { [weak navigator] in navigator?.next(.logout) }
            .store(in: &cancellables)

        // Greeting is a one-shot publisher — no upstream state changes after
        // the user lands here, so `Just` is the simplest fit.
        return Output(
            greeting: Just("Welcome, \(user.name)!").eraseToAnyPublisher(),
            email: Just(user.email).eraseToAnyPublisher()
        )
    }
}

public extension HomeViewModel {
    /// User-event publishers the view streams in.
    struct InputFromView {
        public let logoutTrigger: AnyPublisher<Void, Never>

        public init(logoutTrigger: AnyPublisher<Void, Never>) {
            self.logoutTrigger = logoutTrigger
        }
    }

    /// Reactive bindings the view installs.
    struct Output {
        public let greeting: AnyPublisher<String, Never>
        public let email: AnyPublisher<String, Never>
    }
}
