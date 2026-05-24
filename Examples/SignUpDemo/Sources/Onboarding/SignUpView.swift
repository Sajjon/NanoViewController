// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
import NanoViewControllerCombine
import NanoViewControllerController
import NanoViewControllerCore
import UIKit

/// Plain UIKit form: a header label, two text fields (name + email), a
/// "Sign Up" button, and a spinner overlaid on the button. The button's
/// `isEnabled` and the spinner's animating state are driven by the ViewModel
/// via `populate(with:)`.
public final class SignUpView: UIView {
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Create your account"
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()

    private lazy var nameField = makeField(placeholder: "Name", contentType: .name)
    private lazy var emailField: UITextField = {
        let field = makeField(placeholder: "Email", contentType: .emailAddress)
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        return field
    }()

    private lazy var submitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Sign Up"
        config.baseBackgroundColor = .systemBlue
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        // Disabled until both fields are non-empty (driven by the ViewModel).
        button.isEnabled = false
        return button
    }()

    /// Spinner overlaid on the submit button. White-on-blue for contrast on
    /// the filled button background.
    private lazy var spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        return spinner
    }()

    private lazy var stack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [headerLabel, nameField, emailField, submitButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()

    public init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .systemBackground
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 48),
        ])

        // Centre the spinner on the submit button so the title slides under
        // it (UIButton.Configuration centres its own title; the spinner sits
        // on top during the in-flight state).
        submitButton.addSubview(spinner)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: submitButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: submitButton.centerYAnchor),
        ])
    }

    private func makeField(placeholder: String, contentType: UITextContentType) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textContentType = contentType
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return field
    }
}

extension SignUpView: ViewModelled {
    public typealias ViewModel = SignUpViewModel

    /// Streams the field text + the button-tap into the ViewModel. Uses the
    /// package's `UITextField.textPublisher` (`String?`) lifted to a non-optional
    /// `String` via the `orEmpty` helper from `NanoViewControllerCombine`.
    public var inputFromView: InputFromView {
        InputFromView(
            name: nameField.textPublisher.orEmpty,
            email: emailField.textPublisher.orEmpty,
            submitTrigger: submitButton.tapPublisher
        )
    }

    public func populate(with publishers: ViewModel.Publishers) -> [AnyCancellable] {
        publishers.isSubmitEnabled --> submitButton.isEnabledBinder
        publishers.loadingText --> submitButton.titleBinder(for: .normal)
        publishers.isLoading --> spinner.isAnimatingBinder
    }
}
