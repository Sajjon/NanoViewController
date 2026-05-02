// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import NanoViewControllerCombine

/// User outcomes the SignUp scene can emit. The coordinator subscribes and
/// decides what happens next (here: `signedUp(_:)` advances to Home).
public enum SignUpUserAction {
    case signedUp(SignedUpUser)
}

/// Drives `SignUpView`: validates the (very loose) name + email rules,
/// gates the submit button, and on tap calls the injected service. The
/// returned user is forwarded as `.signedUp` to the parent coordinator.
public final class SignUpViewModel: BaseViewModel<
    SignUpUserAction,
    SignUpViewModel.InputFromView,
    SignUpViewModel.Output
> {
    private let service: SignUpServicing

    public init(service: SignUpServicing) {
        self.service = service
        super.init()
    }

    override public func transform(input: Input) -> Output {
        // Name + email both non-empty → button enabled. Real apps would do
        // proper validation; for a demo this is enough to exercise the
        // reactive enable/disable plumbing.
        let isFormValid: AnyPublisher<Bool, Never> = input.fromView.name
            .combineLatest(input.fromView.email)
            .map { name, email in
                !name.trimmingCharacters(in: .whitespaces).isEmpty
                    && !email.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .eraseToAnyPublisher()

        // On submit-tap: snapshot the latest (name, email), call the service,
        // forward the resulting user as `.signedUp` to the coordinator.
        input.fromView.submitTrigger
            .withLatestFrom(input.fromView.name.combineLatest(input.fromView.email))
            .flatMapLatest { [service] name, email in
                service.signUp(name: name, email: email)
            }
            .sink { [weak self] user in
                self?.navigator.next(.signedUp(user))
            }
            .store(in: &cancellables)

        return Output(isSubmitEnabled: isFormValid)
    }
}

public extension SignUpViewModel {
    /// User-event publishers the view streams in.
    struct InputFromView {
        public let name: AnyPublisher<String, Never>
        public let email: AnyPublisher<String, Never>
        public let submitTrigger: AnyPublisher<Void, Never>

        public init(
            name: AnyPublisher<String, Never>,
            email: AnyPublisher<String, Never>,
            submitTrigger: AnyPublisher<Void, Never>
        ) {
            self.name = name
            self.email = email
            self.submitTrigger = submitTrigger
        }
    }

    /// Reactive bindings the view installs.
    struct Output {
        /// Drives the Sign Up button's `isEnabled`.
        public let isSubmitEnabled: AnyPublisher<Bool, Never>
    }
}
