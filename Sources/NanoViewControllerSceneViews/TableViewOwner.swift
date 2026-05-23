// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Foundation

/// Marker-with-payload protocol for views that own a
/// ``SingleCellTypeTableView``.
///
/// Used by ``BaseTableViewOwner`` to surface the strongly-typed table view
/// to the scene's `populate(with:)` bindings. (Pull-to-refresh wires through
/// ``ScrollViewOwner``, not this protocol — `TableViewOwner` only carries
/// the `Header`/`Cell` generic pair.)
///
/// Conformance is automatic via the ``TableViewSceneView`` typealias —
/// `BaseTableViewOwner<Header, Cell> & TableViewOwner` makes any subclass of
/// `BaseTableViewOwner` a `TableViewOwner` for free.
///
/// ## Example — manual conformance for a custom container
///
/// ```swift
/// final class TwoTableContainerView: UIView, TableViewOwner {
///     // The "primary" table fulfils the protocol.
///     let tableView: SingleCellTypeTableView<Void, RowCell>
///     // Plus a second table that's not exposed via the protocol.
///     private let secondaryTable: SingleCellTypeTableView<Void, OtherCell>
///     // …
/// }
/// ```
@MainActor
public protocol TableViewOwner {
    /// Section header model type — passed through to the diffable data source.
    associatedtype Header

    /// Cell view type. Must conform to ``ListCell`` so it carries an
    /// associated `Model` type the diffable data source can reference.
    associatedtype Cell: ListCell

    /// The owned, strongly-typed table view instance.
    var tableView: SingleCellTypeTableView<Header, Cell> { get }
}
