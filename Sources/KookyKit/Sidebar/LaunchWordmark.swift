import SwiftUI

/// A process-local claim, deliberately not persisted: each application launch
/// gets at most one greeting, not each window, sidebar reveal, or workspace.
@MainActor
final class LaunchWordmarkGate {
    static let shared = LaunchWordmarkGate()
    private var claimed = false

    func claim(reduceMotion: Bool, roll: Int) -> Bool? {
        guard !claimed else { return nil }
        claimed = true
        guard !reduceMotion else { return nil }
        return roll < 10
    }
}

/// Pure timeline shared by both word variants. No timers or terminal state.
struct LaunchWordmarkFrame {
    let offset: Double
    let scale: Double
    let arrivalOpacity: Double
    let splitOpacity: Double
    let colorOpacity: Double
    static let duration = 2.9

    init(elapsed: Double, easterEgg: Bool) {
        let t = max(0, elapsed)
        let points: [(Double, Double, Double)] = [
            (0.42, 7, 1), (0.52, 6, 1), (0.74, 0, 1),
            (0.79, -0.5, 0.94), (0.91, 1.2, 1.015), (1.06, 0, 1)
        ]
        var x = points[0].1
        var s = points[0].2
        for (a, b) in zip(points, points.dropFirst()) {
            if t >= b.0 { x = b.1; s = b.2 }
            else if t >= a.0 {
                let u = Self.smooth((t - a.0) / (b.0 - a.0))
                x = a.1 + (b.1 - a.1) * u
                s = a.2 + (b.2 - a.2) * u
                break
            }
        }
        offset = x
        scale = s
        arrivalOpacity = Self.clamp((t - 0.42) / 0.10)
        let restore = easterEgg ? 1.35 : 1.06
        splitOpacity = 1 - Self.clamp((t - restore) / 0.17)
        let fade = easterEgg ? 2.1 : 1.65
        colorOpacity = 1 - Self.smooth((t - fade) / 0.7)
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
    private static func smooth(_ value: Double) -> Double {
        let u = clamp(value)
        return u * u * (3 - 2 * u)
    }
}

struct LaunchWordmark: View {
    static let font = Font.system(size: 15.5, weight: .bold, design: .rounded)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started: Date?
    @State private var easterEgg = false
    private let gradient = LinearGradient(
        colors: [Color(red: 0.91, green: 0.35, blue: 0.73),
                 Color(red: 0.55, green: 0.34, blue: 0.93)],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        // Stable intrinsic width and baseline; animated pieces never affect
        // the plus button, row alignment, or pointer hit testing.
        Text("Kookoo")
            .font(Self.font)
            .hidden()
            .overlay(alignment: .leading) {
                if let started, !reduceMotion {
                    TimelineView(.animation) { context in
                        let frame = LaunchWordmarkFrame(
                            elapsed: context.date.timeIntervalSince(started), easterEgg: easterEgg
                        )
                        ZStack(alignment: .leading) {
                            lettering(frame).foregroundStyle(Theme.chromeForeground)
                            lettering(frame).foregroundStyle(gradient).opacity(frame.colorOpacity)
                        }
                    }
                } else {
                    Text("Kookoo").font(Self.font).foregroundStyle(Theme.chromeForeground)
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Kookoo")
            .task(id: reduceMotion) {
                guard let special = LaunchWordmarkGate.shared.claim(
                    reduceMotion: reduceMotion, roll: Int.random(in: 0..<100)
                ) else { started = nil; return }
                easterEgg = special
                started = .now
                defer { started = nil }
                // Cancellation on sidebar disappearance or Reduce Motion
                // immediately leaves the static title; the claim isn't reset.
                try? await Task.sleep(for: .seconds(LaunchWordmarkFrame.duration))
            }
    }

    private func lettering(_ frame: LaunchWordmarkFrame) -> some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Text(easterEgg ? "cool" : "Koo")
                    .scaleEffect(x: frame.scale, y: 1, anchor: .trailing)
                    .offset(x: -frame.offset)
                Text(easterEgg ? "cool" : "koo")
                    .scaleEffect(x: frame.scale, y: 1, anchor: .leading)
                    .offset(x: frame.offset)
            }
            .fixedSize()
            .opacity(frame.arrivalOpacity * frame.splitOpacity)
            Text("Kookoo").opacity(1 - frame.splitOpacity)
        }
        .font(Self.font)
    }
}
