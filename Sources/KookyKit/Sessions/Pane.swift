import Foundation

/// One leaf region of a workspace's split tree. Owns its own tab list and
/// active-tab pointer — splitting a workspace creates more `Pane`s, each with
/// an independent tab strip rendered above its content.
@MainActor
@Observable
final class Pane: Identifiable {
    let id: UUID
    var tabs: [Session]
    var activeTabId: UUID?

    // Transient presentation state, deliberately excluded from persistence.
    // Only a user-created split opts in; restored panes and reparented siblings
    // must not replay an entrance when SwiftUI rebuilds the split tree.
    @ObservationIgnored var insertionAnimationPending = false

    func consumeInsertionAnimation() -> Bool {
        let pending = insertionAnimationPending
        insertionAnimationPending = false
        return pending
    }

    init(id: UUID = UUID(), tabs: [Session] = [], activeTabId: UUID? = nil) {
        self.id = id
        self.tabs = tabs
        self.activeTabId = activeTabId
    }

    var activeTab: Session? { tabs.first { $0.id == activeTabId } }
}
