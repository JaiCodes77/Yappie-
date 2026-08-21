import SwiftUI

// Surfaces, labels, keys, lamps, the phosphor meter. Every value comes from `DS`.

// MARK: - Surfaces

/// A quiet raised card. No brushed grain — the old cassette-deck texture.
struct BrushedPanel: View {
    var radius: CGFloat = DS.Radius.panel

    var body: some View {
        DS.Color.panel
            .clipShape(.rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(DS.Color.seam, lineWidth: DS.Border.hairline)
            )
            .shadow(
                color: DS.Shadow.panel.color,
                radius: DS.Shadow.panel.radius,
                x: DS.Shadow.panel.x,
                y: DS.Shadow.panel.y
            )
    }
}

/// Recessed well. Used for the transcript/dictionary page — the amber phosphor surface.
struct Well<Content: View>: View {
    var radius: CGFloat = DS.Radius.panel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(DS.Color.deck, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(DS.Color.copper.opacity(0.28), lineWidth: DS.Border.hairline)
            )
            .shadow(
                color: DS.Shadow.phosphor.color,
                radius: DS.Shadow.phosphor.radius,
                x: DS.Shadow.phosphor.x,
                y: DS.Shadow.phosphor.y
            )
    }
}

/// A row inset on the phosphor page.
struct DeckWindow<Content: View>: View {
    var radius: CGFloat = DS.Radius.control
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(DS.Color.deck, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(DS.Color.inkOnDeck.opacity(0.12), lineWidth: DS.Border.hairline)
            )
    }
}

// MARK: - Labels

/// Condensed editorial label. Sentence case — not silkscreened all-caps.
struct Silkscreen: View {
    let text: String
    var large = false
    var color: Color = DS.Color.silkscreen

    var body: some View {
        Text(text)
            .font(large ? DS.Font.silkscreenLarge : DS.Font.silkscreen)
            .tracking(DS.Font.silkscreenTracking)
            .foregroundStyle(color)
    }
}

// MARK: - Hardware leftovers (kept so call sites compile; they draw nothing)

struct Screw: View {
    var body: some View { Color.clear.frame(width: 0, height: 0) }
}

struct Vents: View {
    var count = 0
    var body: some View { Color.clear.frame(width: 0, height: 0) }
}

/// Record lamp. Red when lit; never used for anything else.
struct Lamp: View {
    let color: Color
    var isLit: Bool
    var size: CGFloat = DS.Material.lampSize

    var body: some View {
        Circle()
            .fill(color.opacity(isLit ? 1 : DS.Material.lampUnlitOpacity))
            .overlay(
                Circle().strokeBorder(DS.Color.seam.opacity(0.5), lineWidth: DS.Border.hairline)
            )
            .frame(width: size, height: size)
            .animation(DS.Motion.lamp, value: isLit)
    }
}

// MARK: - Controls

/// A quiet capsule key. Engaged fill is copper unless the caller passes record red.
struct TransportKey: View {
    let title: String
    var systemImage: String?
    var isEngaged = false
    var engagedColor: Color = DS.Color.record
    var isEnabled = true
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.tight) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .bold))
                }
                Silkscreen(text: title, color: labelColor)
            }
            .frame(minWidth: DS.Material.keyMinWidth)
            .frame(height: DS.Material.keyHeight)
            .padding(.horizontal, DS.Space.base)
            .background(cap)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .onLongPressGesture(minimumDuration: 0) {} onPressingChanged: { pressing in
            withAnimation(pressing ? DS.Motion.press : DS.Motion.release) { isPressed = pressing }
        }
    }

    private var labelColor: Color {
        isEngaged ? engagedColor : DS.Color.ink
    }

    private var cap: some View {
        RoundedRectangle(cornerRadius: DS.Radius.control)
            .fill(isEngaged ? engagedColor.opacity(0.14) : DS.Color.cap)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.control)
                    .strokeBorder(
                        isEngaged ? engagedColor.opacity(0.55) : DS.Color.seam,
                        lineWidth: DS.Border.hairline
                    )
            )
    }
}

// MARK: - Instrumentation

/// A single ink-line that writes the voice. Damped so it breathes instead of strobing.
///
/// Physics live in a reference type, not `@State`, because mutating SwiftUI state inside
/// a `Canvas` draw closure is undefined and floods the log.
struct VUMeter: View {
    let level: Float
    var isActive: Bool

    @State private var movement = InkMovement()

    private final class InkMovement {
        var position: Double = 0
        var velocity: Double = 0
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, at: timeline.date)
            }
        }
        .background(DS.Color.deck)
        .clipShape(.rect(cornerRadius: DS.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.control)
                .strokeBorder(DS.Color.copper.opacity(isActive ? 0.45 : 0.18), lineWidth: DS.Border.hairline)
        )
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, at date: Date) {
        advanceInk()

        let midY = size.height / 2
        let amplitude = size.height * 0.38 * movement.position
        let t = date.timeIntervalSinceReferenceDate
        var path = Path()

        let steps = DS.Material.waveformBars
        for i in 0...steps {
            let x = size.width * CGFloat(i) / CGFloat(steps)
            let phase = Double(i) / Double(steps) * .pi * 4 + t * 5.2
            let y = midY + CGFloat(sin(phase)) * amplitude
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        let color = isActive ? DS.Color.copper : DS.Color.inkOnDeck.opacity(0.35)
        context.stroke(path, with: .color(color), lineWidth: DS.Material.inkLineWidth)
    }

    private func advanceInk() {
        let target = isActive ? Double(min(max(level, 0.08), 1)) : 0.06
        let rising = target > movement.position
        let time = rising ? DS.Motion.needleAttack : DS.Motion.needleRelease
        let stiffness = 1 / time
        let delta = target - movement.position
        movement.velocity += delta * stiffness * 0.16
        movement.velocity *= 0.72
        movement.position += movement.velocity
        movement.position = min(max(movement.position, 0), 1 + DS.Motion.needleOvershoot)
    }
}

/// Monospaced counter on the phosphor page.
struct Readout: View {
    let text: String
    var large = false

    var body: some View {
        Text(text)
            .font(large ? DS.Font.counterLarge : DS.Font.counter)
            .foregroundStyle(DS.Color.inkOnDeck)
    }
}
