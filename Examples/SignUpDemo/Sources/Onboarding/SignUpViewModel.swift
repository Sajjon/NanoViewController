// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import Foundation
import NanoViewControllerCombine
import NanoViewControllerController
import NanoViewControllerCore

/// User outcomes the SignUp scene can emit. The coordinator subscribes and
/// decides what happens next (here: `signedUp(_:)` advances to Home).
public enum SignUpUserAction: Sendable {
    case signedUp(SignedUpUser)
}

// MARK: InputFromView
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
}

// MARK: Publishers
public extension SignUpViewModel {
	/// Reactive bindings the view installs.
	struct Publishers {
		/// Drives the Sign Up button's `isEnabled` (`isFormValid && !isLoading`).
		public let isSubmitEnabled: AnyPublisher<Bool, Never>

		/// `true` while the sign-up service call is in flight. The view
		/// reflects this on a `UIActivityIndicatorView` overlaid on the
		/// submit button.
		public let isLoading: AnyPublisher<Bool, Never>
	}
}
public extension SignUpViewModel.Publishers {
	var loadingText: AnyPublisher<String, Never> {
		isLoading.map { $0 ? "" : "Sign Up" }.eraseToAnyPublisher()
	}
}

/// Drives `SignUpView`: validates the (very loose) name + email rules,
/// gates the submit button, and on tap calls the injected service. The
/// returned user is forwarded as `.signedUp` to the parent coordinator.
public final class SignUpViewModel: BaseViewModel<
    SignUpUserAction,
    SignUpViewModel.InputFromView,
    SignUpViewModel.Publishers
> {
	private let service: SignUpServicing

	public init(service: SignUpServicing) {
		self.service = service
		super.init()
	}

	// MARK: BaseViewModel Overrides
    override public func transform(input: Input) -> Output<Publishers> {
        // Track the in-flight state of the sign-up call so the view can show
        // a spinner and disable the submit button while waiting.
        let activity = ActivityIndicator()

        // Name + email both non-empty → form is valid.
        let isFormValid: AnyPublisher<Bool, Never> = input.fromView.name
            .combineLatest(input.fromView.email)
            .map { name, email in
                !name.trimmingCharacters(in: .whitespaces).isEmpty
                    && !email.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .eraseToAnyPublisher()

        let isLoading = activity.asPublisher()

        // Submit is enabled only when the form is valid AND we're not already
        // mid-request (prevents double-taps from firing two sign-ups).
        let isSubmitEnabled = isFormValid
            .combineLatest(isLoading)
            .map { valid, loading in valid && !loading }
            .eraseToAnyPublisher()

        return Output(
            publishers: Publishers(
                isSubmitEnabled: isSubmitEnabled,
                isLoading: isLoading
            )
        ) {
            // On submit-tap: snapshot the latest (name, email), call the service
            // (tracking activity), forward the resulting user as `.signedUp`.
            input.fromView.submitTrigger
                .withLatestFrom(input.fromView.name.combineLatest(input.fromView.email))
                .map { [service] name, email in
                    service.signUp(name: name, email: email)
                        .trackActivity(activity)
                }
                .switchToLatest()
                .sink { [navigator] user in
                    navigator.next(.signedUp(user))
                }
        }
    }
}
