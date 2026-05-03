// MIT License — Copyright (c) 2018-2026 Open Zesame

import UIKit

/// Protocol for table-view cells that can be populated from a typed `Model`.
///
/// Used together with ``SingleCellTypeTableView`` so the table → cell wiring
/// stays statically type-checked end-to-end.
///
/// ## Example — typed settings cell
///
/// ```swift
/// import NanoViewControllerSceneViews
/// import UIKit
///
/// /// Each row has a title and an optional value.
/// struct SettingsRow {
///     let title: String
///     let value: String?
/// }
///
/// final class SettingsCell: UITableViewCell, CellConfigurable {
///     typealias Model = SettingsRow
///
///     override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
///         super.init(style: .value1, reuseIdentifier: reuseIdentifier)
///         accessoryType = .disclosureIndicator
///     }
///     @available(*, unavailable)
///     required init?(coder _: NSCoder) { fatalError() }
///
///     func configure(model: SettingsRow) {
///         textLabel?.text       = model.title
///         detailTextLabel?.text = model.value
///     }
/// }
///
/// // The table is then strongly typed:
/// let table = SingleCellTypeTableView<Void, SettingsCell>(style: .insetGrouped)
/// table.sections.on([
///     SectionModel(model: (), items: [
///         SettingsRow(title: "Currency", value: "USD"),
///         SettingsRow(title: "Network",  value: "Mainnet"),
///     ]),
/// ])
/// ```
@MainActor
public protocol CellConfigurable {
    /// The model type this cell knows how to render.
    associatedtype Model

    /// Renders `model` into the cell.
    ///
    /// Called every time the table dequeues the cell for a new index path.
    /// Implementations should rebuild any non-static state from `model`
    /// (cells get reused — assume nothing about prior state).
    ///
    /// - Parameter model: The data to render.
    func configure(model: Model)
}
