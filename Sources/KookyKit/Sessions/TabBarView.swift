import AppKit
import SwiftUI

/// Per-pane tab strip — each split region renders its own. The "+" button
/// targets the pane it sits in.
struct TabBarView: View {
    @Bindable var pane: Pane
    @Bindable var workspace: Workspace
    let store: WorkspaceStore

    @State private var isAddMenuOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.space1) {
            // Only the tab rail scrolls. Creation and split controls are
            // separate, stable targets even in a narrow pane.
            GeometryReader { geometry in
                ScrollViewReader { scroll in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(pane.tabs.enumerated()), id: \.element.id) { index, tab in
                                DraggableTabRow(
                                    tab: tab,
                                    pane: pane,
                                    workspace: workspace,
                                    store: store,
                                    myIndex: index,
                                    canCloseToRight: index < pane.tabs.count - 1
                                )
                                .frame(width: Theme.paneTabWidth(
                                    available: geometry.size.width,
                                    count: pane.tabs.count
                                ))
                                .id(tab.id)
                            }
                        }
                    }
                    .onChange(of: pane.activeTabId) { _, id in
                        // Keyboard selection and creation must reveal the new
                        // tab even when not all tabs fit.
                        if let id { scroll.scrollTo(id) }
                    }
                }
            }
            .frame(height: Theme.paneTabRailHeight)
            .background(Theme.paneTabRail, in: Capsule())
            .clipShape(Capsule())
            // Window zoom belongs only to the tab rail, never to the pane
            // controls. Keep the existing native window double-click behavior.
            .background {
                TabBarDoubleClickHandler {
                    NSApplication.shared.keyWindow?.performZoom(nil)
                }
            }

            addButton
            splitButtons
        }
        .padding(.horizontal, Theme.paneTabHorizontalInset)
        .frame(height: Theme.paneTabBarHeight)
    }

    /// Split Right is side-by-side (.horizontal), as for ⌘D. Split Down
    /// remains available in the tab context / application menu and via ⌘⇧D.
    private var splitButtons: some View {
        HStack(spacing: Theme.space1) {
            if workspace.canZoom {
                let isZoomed = workspace.isZoomed(pane.id)
                HoverableIconButton(
                    systemName: isZoomed
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right",
                    fontSize: 11,
                    size: Theme.chromeToolbarButtonSize,
                    help: isZoomed ? "Exit zoom (⌘⇧E)" : "Zoom pane (⌘⇧E)"
                ) {
                    withAnimation(reduceMotion ? nil : Theme.chromeTransition) {
                        store.toggleZoom(in: workspace, paneId: pane.id)
                    }
                }
                .background(isZoomed ? Theme.paneTabRail : .clear, in: Capsule())
                .accessibilityValue(isZoomed ? "Zoomed" : "Not zoomed")
            }
            HoverableIconButton(
                systemName: "square.split.2x1",
                fontSize: 11,
                size: Theme.chromeToolbarButtonSize,
                help: "Split Right (⌘D)"
            ) {
                store.splitPane(pane, orientation: .horizontal, in: workspace)
            }
        }
    }

    private var addButton: some View {
        AddTabButton(
            pane: pane,
            workspace: workspace,
            store: store,
            isMenuOpen: $isAddMenuOpen
        )
    }
}

/// Double-clicking the tab bar triggers macOS Zoom (filled screen, dock and
/// menu kept) — the same behavior as double-clicking the system title bar.
/// Capture it at the AppKit event boundary: a gesture recognizer attached to
/// SwiftUI's background host is not guaranteed to sit on the event-hit view,
/// so it can silently miss clicks from tab rows.
private struct TabBarDoubleClickHandler: NSViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeNSView(context: Context) -> AnchorView {
        AnchorView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: AnchorView, context: Context) {
        context.coordinator.action = action
    }

    @MainActor
    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }
    }

    @MainActor
    final class AnchorView: NSView {
        private let coordinator: Coordinator
        private var monitor: Any?

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                guard let self,
                      event.clickCount == 2,
                      event.window === self.window,
                      bounds.contains(convert(event.locationInWindow, from: nil))
                else { return event }
                coordinator.action()
                return event
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil { removeMonitor() }
            super.viewWillMove(toWindow: newWindow)
        }

        private func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

/// `+` button doubling as the "drop at end" target — dragging a tab here
/// (from this pane or another) appends it after the last tab, which is
/// otherwise unreachable inside a horizontal `ScrollView` where there's no
/// flex space for a trailing drop zone.
private struct AddTabButton: View {
    @Bindable var pane: Pane
    @Bindable var workspace: Workspace
    @Bindable var store: WorkspaceStore
    @Binding var isMenuOpen: Bool

    @State private var isTargeted = false

    var body: some View {
        HoverableIconButton(
            systemName: "plus",
            fontSize: 12,
            size: Theme.chromeToolbarButtonSize,
            help: "New tab"
        ) {
            // Two short-circuit paths that skip the popover entirely:
            //   1. user picked a default agent in Settings — open it
            //   2. every coding agent is hidden so the popover would show
            //      just Terminal anyway — open Terminal
            let model = KookySettingsModel.shared
            if let defaultTemplate = AgentTemplate.defaultLaunchTemplate(model: model) {
                store.addTab(in: workspace, pane: pane, template: defaultTemplate)
            } else if AgentTemplate.visibleOrdered(model: model).count <= 1 {
                store.addTab(in: workspace, pane: pane, template: .terminal)
            } else {
                isMenuOpen.toggle()
            }
        }
        .background(Theme.paneTabRail, in: Capsule())
        // The pinned plus still accepts drops at the end of the tab strip,
        // even while the last tab is scrolled out of view.
        .dropIndicator(active: isTargeted, on: .leading, offset: -3)
        .popover(isPresented: $isMenuOpen, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                // In an SSH workspace every choice opens on the remote — the
                // suffix keeps that from surprising anyone mid-click.
                let sshSuffix = workspace.sshRemoteHost == nil ? "" : " on SSH"
                ForEach(AgentTemplate.visibleOrdered(model: KookySettingsModel.shared)) { template in
                    KookyMenuRow(
                        title: template.title + sshSuffix,
                        localizesTitle: false,
                        highlight: .launcher
                    ) {
                        AgentIconView(asset: template.iconAsset, fallbackSymbol: template.symbol, size: 16)
                    } action: {
                        store.addTab(in: workspace, pane: pane, template: template)
                        isMenuOpen = false
                    }
                }
            }
            // Leave enough inset that the first hover outline clears the
            // native popover's rounded top corners.
            .padding(Theme.space2)
            .frame(minWidth: 220)
            .background(Theme.chromeBackground)
        }
        .dropDestination(for: String.self) { dropped, _ in
            defer { store.draggingTabId = nil }
            guard let id = dropped.first.flatMap(UUID.init) else { return false }
            return withAnimation(.easeInOut(duration: 0.18)) {
                store.handleTabDrop(droppedId: id, to: pane, at: pane.tabs.count, in: workspace)
            }
        } isTargeted: { isTargeted = $0 }
    }
}

/// Wraps `TabBarItem` with drag source + drop target. Same-pane drops
/// reorder; cross-pane drops move the session into this pane (source pane
/// collapses if it runs out of tabs). The 2pt indicator follows drag
/// direction — `leading` for left-of-target sources, `trailing` for
/// right-of-target — so the line always shows where the dropped tab lands.
private struct DraggableTabRow: View {
    @Bindable var tab: Session
    @Bindable var pane: Pane
    @Bindable var workspace: Workspace
    @Bindable var store: WorkspaceStore
    let myIndex: Int
    let canCloseToRight: Bool

    @State private var isTargeted = false

    var body: some View {
        let originIndex: Int? = {
            guard let id = store.draggingTabId, id != tab.id else { return nil }
            return pane.tabs.firstIndex(where: { $0.id == id })
        }()
        let dragsRightward = (originIndex ?? Int.max) < myIndex
        let edge: Alignment = dragsRightward ? .trailing : .leading
        let isSelfDrag = store.draggingTabId == tab.id

        TabBarItem(
            tab: tab,
            isActive: pane.activeTabId == tab.id,
            shortcut: MenuTag.shortcut(forTabIndex: myIndex, tabCount: pane.tabs.count),
            canCloseToRight: canCloseToRight,
            onActivate: { store.activateTab(tab, in: workspace) },
            onClose: { ConfirmCloseTab.request(tab, in: workspace, store: store) },
            onCloseOthers: { store.closeOtherTabs(keeping: tab, in: workspace) },
            onCloseToRight: { store.closeTabsToRight(of: tab, in: workspace) },
            onDuplicate: { store.duplicateTab(tab, in: workspace) },
            onRename: { store.renameTab(tab, to: $0) },
            onSplit: { store.splitPane(pane, orientation: $0, in: workspace) },
            onMoveToNewWindow: { store.moveTabToNewWindow(tab.id) }
        )
        .dropIndicator(active: isTargeted && !isSelfDrag, on: edge)
        .onDrag {
            store.draggingTabId = tab.id
            return NSItemProvider(object: tab.id.uuidString as NSString)
        }
        .dropDestination(for: String.self) { dropped, _ in
            defer { store.draggingTabId = nil }
            guard let id = dropped.first.flatMap(UUID.init) else { return false }
            return withAnimation(.easeInOut(duration: 0.18)) {
                store.handleTabDrop(droppedId: id, to: pane, at: myIndex, in: workspace)
            }
        } isTargeted: { isTargeted = $0 }
    }
}
