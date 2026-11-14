import SwiftUI

/// A pane is one card, not a rounded container around the whole split tree.
/// Insets stay at the leaves so nested splits never accumulate extra gutters.
enum PaneCardStyle {
    static let inset: CGFloat = 3
    static let cornerRadius: CGFloat = 10
    static let terminalInset: CGFloat = 5
    static let insertionScale: CGFloat = 0.975
    static let insertionOpacity: Double = 0.65

    static func animatesInsertion(pending: Bool, reduceMotion: Bool) -> Bool {
        pending && !reduceMotion
    }
}

struct PaneCardChrome: ViewModifier {
    let isFocused: Bool
    // Sidebars retain their existing glass/chrome material inside the same
    // card geometry; terminals keep their own opaque surface background.
    var fillsTerminalSurface = true

    func body(content: Content) -> some View {
        let outline = RoundedRectangle(cornerRadius: PaneCardStyle.cornerRadius, style: .continuous)
        content
            .background(fillsTerminalSurface ? Color(nsColor: Theme.terminalSurface) : .clear)
            .clipShape(outline)
            .overlay {
                outline.strokeBorder(
                    Theme.chromeForeground.opacity(isFocused ? 0.20 : 0.10),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            }
            .padding(PaneCardStyle.inset)
    }
}

/// Presentation-only spring: the terminal is laid out at its final size once.
/// Animating split fractions would repeatedly send SIGWINCH to shells/TUIs.
/// This transform neither reconstructs the session nor changes its cell grid.
struct PaneInsertionPresentation: ViewModifier {
    let pane: Pane
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered: Bool

    init(pane: Pane) {
        self.pane = pane
        _entered = State(initialValue: !pane.insertionAnimationPending)
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(entered || reduceMotion ? 1 : PaneCardStyle.insertionScale)
            .opacity(entered || reduceMotion ? 1 : PaneCardStyle.insertionOpacity)
            .onAppear {
                let pending = pane.consumeInsertionAnimation()
                if PaneCardStyle.animatesInsertion(pending: pending, reduceMotion: reduceMotion) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        entered = true
                    }
                } else {
                    entered = true
                }
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced { entered = true }
            }
    }
}
