// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import NanoViewControllerCore
import UIKit

/// A no-op view model used by ``NanoViewControllerWithoutVM`` to route static
/// UIKit views through the same hosting machinery as ordinary scenes.
@MainActor
public final class NanoViewControllerWithoutVMViewModel: AbstractViewModel<
    NanoViewControllerWithoutVMViewModel.InputFromView,
    NanoViewControllerWithoutVMViewModel.Publishers,
    Never
> {
    public struct InputFromView {}
    public struct Publishers {}

    override public func transform(input _: Input) -> Output<Publishers, Never> {
        Output(publishers: Publishers())
    }
}

/// Wraps a plain `UIView` so it satisfies ``ContentView`` without requiring
/// app code to write a dummy view model.
@MainActor
public final class NanoViewControllerWithoutVMContentView<Content: UIView & EmptyInitializable>: UIView, ViewModelled {
    public typealias ViewModel = NanoViewControllerWithoutVMViewModel

    public let contentView: Content

    public init() {
        self.contentView = Content()
        super.init(frame: .zero)

        addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }

    public var inputFromView: InputFromView {
        InputFromView()
    }
}

/// Hosts a static UIKit view with no app-facing view model.
///
/// Use this for screens that still want the package's controller chrome
/// behavior but do not have user input, output bindings, or navigation events.
open class NanoViewControllerWithoutVM<Content: UIView & EmptyInitializable>:
    NanoViewController<NanoViewControllerWithoutVMContentView<Content>>
{
    public init() {
        super.init(viewModel: NanoViewControllerWithoutVMViewModel())
    }

    public required init(viewModel: NanoViewControllerWithoutVMViewModel) {
        super.init(viewModel: viewModel)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        interfaceBuilderSucks
    }
}
