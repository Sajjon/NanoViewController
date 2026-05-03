// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
import UIKit

/// Marker protocol that table-view subclasses adopt to expose a reactive
/// selection stream.
///
/// Class-bound (`AnyObject`) so it composes with `UITableView` subclasses
/// without requiring `where Self: UIView` clutter. ``SingleCellTypeTableView``
/// is the standard conformer; consumers can declare conformance on their own
/// table-view subclasses to participate in the same publisher.
///
/// Views that want the `UITableView.itemSelectedPublisher` helper (defined below) must conform
/// to this — that property forwards to the subclass-supplied publisher.
@MainActor
public protocol SelectionPublishing: AnyObject {
    /// Emits each `IndexPath` selected by the user.
    var selectionPublisher: AnyPublisher<IndexPath, Never> { get }
}

public extension UITableView {
    /// Publisher of selected row indices.
    ///
    /// Forwards to whichever ``SelectionPublishing`` subclass actually
    /// implements the publisher (project-specific subclasses like
    /// ``SingleCellTypeTableView``). A plain `UITableView` that doesn't
    /// conform yields an empty publisher — graceful degradation rather than
    /// trapping, so misuse surfaces as "no taps observed" rather than
    /// crashing the app.
    ///
    /// ## Example
    ///
    /// ```swift
    /// final class SettingsView: HeaderlessTableViewSceneView<SettingsCell>, EmptyInitializable {
    ///     required init() { super.init(style: .insetGrouped) }
    ///     var inputFromView: SettingsViewModel.Input.FromView {
    ///         SettingsViewModel.InputFromView(
    ///             selected: tableView.itemSelectedPublisher
    ///         )
    ///     }
    /// }
    /// ```
    var itemSelectedPublisher: AnyPublisher<IndexPath, Never> {
        guard let selectableTable = self as? SelectionPublishing else {
            return Empty().eraseToAnyPublisher()
        }
        return selectableTable.selectionPublisher
    }
}
