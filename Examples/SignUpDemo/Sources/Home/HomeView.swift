// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
import NanoViewControllerCombine
import NanoViewControllerController
import NanoViewControllerCore
import UIKit

/// Two stacked labels (greeting + email) and a destructive "Log out" button
/// at the bottom. Both labels are driven by ViewModel publishers so the View
/// itself stays state-free.
public final class HomeView: UIView {
    private lazy var greetingLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var emailLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var logoutButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = "Log out"
        config.baseForegroundColor = .systemRed
        return UIButton(configuration: config)
    }()

    private lazy var topStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [greetingLabel, emailLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
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
        addSubview(topStack)
        addSubview(logoutButton)
        topStack.translatesAutoresizingMaskIntoConstraints = false
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // Greeting cluster centred vertically in the upper half.
            topStack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            topStack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            topStack.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),

            // Logout pinned to the safe-area bottom.
            logoutButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            logoutButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            logoutButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }
}

extension HomeView: ViewModelled {
    public typealias ViewModel = HomeViewModel

    public var inputFromView: InputFromView {
        InputFromView(logoutTrigger: logoutButton.tapPublisher)
    }

    public func populate(with output: ViewModel.Output) -> [AnyCancellable] {
        output.greeting --> greetingLabel
        output.email --> emailLabel
    }
}
