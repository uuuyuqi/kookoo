import SwiftUI

struct TabBarItem: View {
    @Bindable var tab: Session
    let isActive: Bool
    let isLeadingTab: Bool
    let canCloseToRight: Bool
    let onActivate: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseToRight: () -> Void
    let onDuplicate: () -> Void
    let onRename: (String) -> Void
    let onSplit: (SplitOrientation) -> Void
    let onMoveToNewWindow: () -> Void

    @State private var isHovered = false
    @State private var isContextMenuOpen = false
    @State private var isRenameOpen = false
    @State private var pendingRename = ""

    var body: some View {
        HStack(spacing: 7) {
            commandStatusDot
            AgentIconView(asset: tab.displayAgent.iconAsset, fallbackSymbol: tab.displayAgent.symbol, size: 15)
            Text(tab.title)
                .font(Theme.display(12, weight: isActive ? .medium : .regular))
                .lineLimit(1)
            HoverableIconButton(
                systemName: "xmark",
                fontSize: 9,
                size: Theme.paneTabCloseButtonSize,
                help: "Close tab",
                action: onClose
            )
            .revealed(isHovered || isActive)
        }
        .foregroundStyle(isActive ? Theme.chromeForeground : Theme.chromeForeground.opacity(0.62))
        .padding(.horizontal, 11)
        .padding(.vertical, Theme.paneTabVerticalPadding)
        .background {
            if !isActive && isHovered {
                RoundedRectangle(cornerRadius: Theme.chromeSelectionCornerRadius, style: .continuous)
                    .fill(Theme.chromeHover)
            }
        }
        // Keep labels centered in the original header; only the selected
        // decoration reaches into the former standalone separator row.
        .frame(height: Theme.paneTabBarHeight)
        .padding(.bottom, Theme.paneTabSeparatorHeight)
        .background {
            if isActive {
                // Only paint outside the row. The tab contents, hit area,
                // and spacing do not shift when selection changes.
                let foot = Theme.paneTabFootRadius
                let outline = AttachedTabOutline(
                    flushLeading: isLeadingTab,
                    foot: foot,
                    cornerRadius: Theme.chromeSelectionCornerRadius,
                    lineWidth: Theme.paneTabSeparatorHeight
                )
                outline.fillShape
                    .fill(Color(nsColor: Theme.terminalSurface))
                    .overlay {
                        outline.stroke(Theme.chromeSeparator, lineWidth: Theme.paneTabSeparatorHeight)
                    }
                    .padding(.top, Theme.space1)
                    .padding(.leading, -(isLeadingTab ? Theme.paneTabLeadingInset : foot))
                    .padding(.trailing, -foot)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onActivate)
        .onHover { isHovered = $0 }
        // Selection is a discrete navigation state, not a layout transition.
        // Animating it delays the visual handoff while the terminal surface is
        // already being switched underneath.
        .transaction { transaction in
            if isActive { transaction.animation = nil }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .overlay(RightClickCatcher { _ in isContextMenuOpen = true })
        .overlay(MiddleClickCatcher { onClose() })
        .popover(isPresented: $isContextMenuOpen, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                KookyMenuRow(title: "Close Tab", shortcut: "⌘W") {
                    isContextMenuOpen = false
                    onClose()
                }
                KookyMenuRow(title: "Close Other Tabs") {
                    isContextMenuOpen = false
                    onCloseOthers()
                }
                KookyMenuRow(title: "Close Tabs to the Right", isDisabled: !canCloseToRight) {
                    isContextMenuOpen = false
                    onCloseToRight()
                }
                KookyMenuDivider()
                KookyMenuRow(title: "Split Right", shortcut: "⌘D") {
                    isContextMenuOpen = false
                    onSplit(.horizontal)
                }
                KookyMenuRow(title: "Split Down", shortcut: "⌘⇧D") {
                    isContextMenuOpen = false
                    onSplit(.vertical)
                }
                KookyMenuRow(title: "Move to New Window") {
                    isContextMenuOpen = false
                    onMoveToNewWindow()
                }
                KookyMenuDivider()
                KookyMenuRow(title: "Rename Tab…", shortcut: "⌘R") {
                    isContextMenuOpen = false
                    beginRename(deferred: true)
                }
                KookyMenuRow(title: "Duplicate Tab") {
                    isContextMenuOpen = false
                    onDuplicate()
                }
                KookyMenuDivider()
                RevealInFinderMenuRow(url: tab.currentDirectory) { isContextMenuOpen = false }
            }
            .padding(Theme.space1)
            .frame(minWidth: 240)
            .background(Theme.chromeBackground)
        }
        .popover(isPresented: $isRenameOpen, arrowEdge: .bottom) {
            KookyRenameField(placeholder: "Tab title", text: $pendingRename) {
                onRename(pendingRename)
                isRenameOpen = false
            }
        }
        .onChange(of: tab.renameRequested) { _, requested in
            // ⌘R routes here via `Session.renameRequested`. Consume the flag
            // so the next ⌘R re-fires.
            guard requested else { return }
            tab.renameRequested = false
            beginRename(deferred: false)
        }
    }

    /// Seed the edit field from the current title and open the rename popover.
    /// `deferred` waits one runloop tick — needed from the context menu, where
    /// that popover is mid-dismiss and back-to-back popovers off the same
    /// anchor glitch; the ⌘R path opens synchronously. Skips when already open
    /// so a re-trigger mid-edit can't wipe what the user is typing.
    private func beginRename(deferred: Bool) {
        guard !isRenameOpen else { return }
        pendingRename = tab.customTitle ?? tab.title
        if deferred {
            DispatchQueue.main.async { isRenameOpen = true }
        } else {
            isRenameOpen = true
        }
    }

    /// Shows only on non-zero exit. Successful runs intentionally leave the
    /// row clean — a green dot on every command would dominate the chrome.
    @ViewBuilder
    private var commandStatusDot: some View {
        if let exit = tab.lastCommandExit, exit != 0 {
            Circle()
                .fill(Theme.activityFailure)
                .frame(width: 5, height: 5)
                .help(Self.statusTooltip(exit: exit, duration: tab.lastCommandDuration))
        }
    }

    private static func statusTooltip(exit: Int, duration: TimeInterval?) -> String {
        guard let duration else {
            return String.localizedStringWithFormat(
                String(localized: "exit %d", bundle: .kookyResources),
                exit
            )
        }
        return String.localizedStringWithFormat(
            String(localized: "exit %d · %@", bundle: .kookyResources),
            exit,
            formatDuration(duration)
        )
    }

    /// Internal: the Session Info inspector renders the same OSC 133;D
    /// duration — one formatter, or the tab tooltip and the inspector drift
    /// on the next tier tweak. (`ToolCallActivityPill.formatElapsed` stays a
    /// deliberately distinct style — see M5.bbbb.)
    static func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return "\(Int((seconds * 1000).rounded()))ms" }
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let minutes = Int(seconds / 60)
        let rem = Int(seconds.truncatingRemainder(dividingBy: 60).rounded())
        return "\(minutes)m \(rem)s"
    }
}

/// The open stroke follows the top and sides, then turns outward into the
/// divider. The fill extends through the divider's lower half so a seam
/// cannot peek through under the selected tab.
struct AttachedTabOutline: Shape {
    let flushLeading: Bool
    let foot: CGFloat
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    private var fillsToBottom = false

    init(flushLeading: Bool, foot: CGFloat, cornerRadius: CGFloat, lineWidth: CGFloat) {
        self.flushLeading = flushLeading
        self.foot = foot
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    var fillShape: Self {
        var copy = self
        copy.fillsToBottom = true
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let halfLine = lineWidth / 2
        let outerLeft = flushLeading ? rect.minX : rect.minX + halfLine
        let outerRight = rect.maxX - halfLine
        let left = flushLeading ? outerLeft : outerLeft + foot
        let right = outerRight - foot
        let top = rect.minY + halfLine
        let baseline = rect.maxY - halfLine
        let radius = min(cornerRadius, (right - left) / 2)

        var path = Path()
        if flushLeading {
            // The pane card supplies the left outline; don't double it.
            path.move(to: CGPoint(x: outerLeft, y: top))
        } else {
            path.move(to: CGPoint(x: outerLeft, y: baseline))
            path.addQuadCurve(
                to: CGPoint(x: left, y: baseline - foot),
                control: CGPoint(x: left, y: baseline)
            )
            path.addLine(to: CGPoint(x: left, y: top + radius))
            path.addQuadCurve(
                to: CGPoint(x: left + radius, y: top),
                control: CGPoint(x: left, y: top)
            )
        }
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addQuadCurve(
            to: CGPoint(x: right, y: top + radius),
            control: CGPoint(x: right, y: top)
        )
        path.addLine(to: CGPoint(x: right, y: baseline - foot))
        path.addQuadCurve(
            to: CGPoint(x: outerRight, y: baseline),
            control: CGPoint(x: right, y: baseline)
        )
        if fillsToBottom {
            path.addLine(to: CGPoint(x: outerRight, y: rect.maxY))
            path.addLine(to: CGPoint(x: outerLeft, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}
