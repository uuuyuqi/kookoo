import SwiftUI
import XCTest
@testable import KookyKit

final class InlineWorkspaceRenameStateTests: XCTestCase {
    func testEnterReturnsDraftOnlyOnce() {
        var edit = InlineWorkspaceRenameState()
        edit.begin(title: "Original")
        edit.text = "Renamed"
        XCTAssertEqual(edit.finish(commit: true), "Renamed")
        XCTAssertFalse(edit.isEditing)
        XCTAssertNil(edit.finish(commit: true), "the subsequent focus loss must not save twice")
    }

    func testEscapeAndRemovalCancelWithoutSaving() {
        var edit = InlineWorkspaceRenameState()
        edit.begin(title: "Original")
        edit.text = "Not saved"
        XCTAssertNil(edit.finish(commit: false))
        XCTAssertNil(edit.finish(commit: true), "blur after cancellation must not save")
    }

    func testRepeatedRequestPreservesTypingAndNewEditUsesFreshTitle() {
        var edit = InlineWorkspaceRenameState()
        edit.begin(title: "Original")
        edit.text = "In progress"
        edit.begin(title: "External update")
        XCTAssertEqual(edit.text, "In progress")
        _ = edit.finish(commit: false)
        edit.begin(title: "Current title")
        XCTAssertEqual(edit.text, "Current title")
    }

    func testBlankDraftStillCommitsForDefaultTitleReset() {
        var edit = InlineWorkspaceRenameState()
        edit.begin(title: "Custom")
        edit.text = ""
        XCTAssertEqual(edit.finish(commit: true), "")
    }
}

@MainActor
final class InlineWorkspaceRenameStoreTests: XCTestCase {
    private func makeStore() -> WorkspaceStore {
        WorkspaceStore(
            persistence: InMemoryPersistence(),
            engineFactory: { TestEngine() },
            optionsProvider: { _ in nil },
            resumeProvider: { true },
            noteRecentFolder: { _ in }
        )
    }

    func testRenameRevealsFullSidebarFromCompactAndFilesMode() throws {
        let store = makeStore()
        defer { store.terminate() }
        let workspace = try XCTUnwrap(store.active)
        store.setSidebarMode(.compact)
        store.setSidebarContent(.files)
        store.requestRenameWorkspace(workspace)
        XCTAssertEqual(store.sidebarMode, .full)
        XCTAssertEqual(store.sidebarContent, .workspaces)
        XCTAssertEqual(store.pendingRenameWorkspace?.id, workspace.id)
    }

    func testContextRequestTargetsNamedRowWithoutSwitchingWorkspace() throws {
        let store = makeStore()
        defer { store.terminate() }
        let original = try XCTUnwrap(store.active)
        let second = store.addWorkspace(workingDirectory: URL(fileURLWithPath: "/tmp/kookoo-inline-rename"))
        XCTAssertEqual(store.active?.id, second.id)
        store.requestRenameWorkspace(original)
        XCTAssertEqual(store.pendingRenameWorkspace?.id, original.id)
        XCTAssertEqual(store.active?.id, second.id)
    }

    func testDeletedWorkspaceCannotReceiveDeferredRename() throws {
        let store = makeStore()
        defer { store.terminate() }
        let removed = try XCTUnwrap(store.active)
        _ = store.addWorkspace(workingDirectory: URL(fileURLWithPath: "/tmp/kookoo-inline-rename"))
        store.requestRenameWorkspace(removed)
        store.closeWorkspace(removed)
        XCTAssertNil(store.pendingRenameWorkspace)
        store.requestRenameWorkspace(removed)
        XCTAssertNil(store.pendingRenameWorkspace)
        store.renameWorkspace(removed, to: "Late callback")
        XCTAssertNil(removed.customTitle)
    }
}
