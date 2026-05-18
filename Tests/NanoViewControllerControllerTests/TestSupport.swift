// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Foundation

@MainActor
func pumpMainRunLoop() {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
}
