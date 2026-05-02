// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import UIKit

// MARK: - sinkOnMain

public extension Publisher where Failure == Never {
    /// Subscribes and dispatches each value through the supplied scheduling
    /// closure before invoking `receiveValue`.
    ///
    /// In production the default `DispatchQueue.main.async` closure makes this
    /// equivalent to `.receive(on: DispatchQueue.main).sink { … }`. Tests can
    /// pass `{ $0() }` to deliver values synchronously, which lets coordinator
    /// tests assert on side effects without pumping the runloop.
    ///
    /// (Previously this used `Container.shared.mainScheduler()` to resolve a
    /// scheduler from the consumer's DI container. The closure form drops the
    /// dependency on Factory entirely so the package stays DI-agnostic.)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Production — default schedule hops to the main queue.
    /// viewModel.navigator.navigation
    ///     .sinkOnMain { [weak self] step in self?.handle(step) }
    ///     .store(in: &cancellables)
    ///
    /// // In a coordinator test — invoke synchronously.
    /// let coordinator = OnboardingCoordinator(...)
    /// coordinator.start()
    ///
    /// // Drive the navigator's pulse and assert immediately.
    /// var captured: [SignUpStep] = []
    /// signUpVM.navigator.navigation
    ///     .sinkOnMain(schedule: { $0() }) { captured.append($0) }
    ///     .store(in: &bag)
    ///
    /// signUpVM.navigator.next(.signedUp(user))
    /// XCTAssertEqual(captured, [.signedUp(user)])      // already delivered
    /// ```
    ///
    /// - Parameters:
    ///   - schedule: Closure that decides how to dispatch the receive callback.
    ///     Defaults to `DispatchQueue.main.async`.
    ///   - receiveValue: The handler invoked for each received value.
    /// - Returns: The cancellable subscription.
    func sinkOnMain(
        schedule: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
        _ receiveValue: @escaping (Output) -> Void
    ) -> AnyCancellable {
        sink { value in
            schedule { receiveValue(value) }
        }
    }
}

// MARK: - --> binding operator

/// Binding operator. Reads as "the publisher on the left flows into the binder
/// on the right".
///
/// ## Example
///
/// ```swift
/// // String publisher into a label.
/// output.title --> titleLabel
///
/// // Bool publisher into a UIControl's enabled state.
/// output.isLoading.map { !$0 } --> primaryButton.isEnabledBinder
///
/// // Custom binder.
/// output.elevation --> card.elevationBinder
/// ```
infix operator -->

/// Binds a `Never`-failing publisher to a ``Binder``.
///
/// Hops every emission to `RunLoop.main` and forwards through `binder.on(_:)`.
/// Returns the resulting `AnyCancellable` so callers can collect it into a bag.
///
/// ## Example
///
/// ```swift
/// func populate(with output: ViewModel.OutputVM) -> [AnyCancellable] {
///     [
///         output.cardElevation --> card.elevationBinder,
///         output.isEnabled     --> button.isEnabledBinder,
///     ]
/// }
/// ```
@discardableResult
public func --> <T>(publisher: AnyPublisher<T, Never>, binder: Binder<T>) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { binder.on($0) }
}

/// `-->` overload: binds a non-optional publisher into a `Binder` that accepts
/// an optional. Implicitly lifts the value to `.some(...)`.
///
/// ## Example
///
/// ```swift
/// // textBinder is Binder<String?>; the publisher is AnyPublisher<String, Never>.
/// output.username --> textField.textBinder
/// ```
@discardableResult
public func --> <T>(publisher: AnyPublisher<T, Never>, binder: Binder<T?>) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { binder.on($0) }
}

/// `-->` overload: binds an optional publisher into a `Binder` of the same
/// optional type.
///
/// ## Example
///
/// ```swift
/// output.optionalAvatar --> avatarView.imageBinder      // Binder<UIImage?>
/// ```
@discardableResult
public func --> <T>(publisher: AnyPublisher<T?, Never>, binder: Binder<T?>) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { binder.on($0) }
}

/// `-->` overload: binds a string publisher directly into a `UILabel`'s `text`.
///
/// Sugar for `output.title --> label.textBinder` — slightly more compact at
/// the call site.
///
/// ## Example
///
/// ```swift
/// output.title --> titleLabel       // identical to: output.title --> titleLabel.textBinder
/// ```
@discardableResult
public func --> (publisher: AnyPublisher<String, Never>, label: UILabel) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { [weak label] in label?.text = $0 }
}

/// `-->` overload: same as the `String` variant but for optional strings.
@discardableResult
public func --> (publisher: AnyPublisher<String?, Never>, label: UILabel) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { [weak label] in label?.text = $0 }
}

/// `-->` overload: binds a string publisher directly into a `UITextView`'s `text`.
///
/// ## Example
///
/// ```swift
/// output.bodyText --> bodyTextView
/// ```
@discardableResult
public func --> (publisher: AnyPublisher<String, Never>, textView: UITextView) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { [weak textView] in textView?.text = $0 }
}

/// `-->` overload: same as the `String` variant but for optional strings.
@discardableResult
public func --> (publisher: AnyPublisher<String?, Never>, textView: UITextView) -> AnyCancellable {
    publisher.receive(on: RunLoop.main).sink { [weak textView] in textView?.text = $0 }
}
