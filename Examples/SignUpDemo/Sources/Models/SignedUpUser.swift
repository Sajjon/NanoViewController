// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Foundation

/// The single domain model in this demo. Returned by `SignUpServicing.signUp`
/// after a successful (faked) registration; consumed by Home to render the
/// "Welcome, <name>" greeting.
public struct SignedUpUser: Equatable, Sendable {
    /// Server-assigned identifier. The dummy service mints a fresh `UUID()`
    /// per signup; a real backend would return its own ID here.
    public let id: UUID
    public let name: String
    public let email: String

    public init(id: UUID, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}
