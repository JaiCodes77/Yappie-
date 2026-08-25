import SwiftUI

// Surfaces, labels, controls, the level meter. Every value comes from `DS`.

// MARK: - Surfaces

/// A raised card on the chassis: sheets, settings sections, comparison rows.
struct Card<Content: View>: View {
    var radius: CGFloat = DS.Radius.panel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(DS.Color.bar, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(DS.Color.seam, lineWidth: DS.Border.hairline)
            )
            .shadow(
                color: DS.Shadow.card.color,
                radius: DS.Shadow.card.radius,
                x: DS.Shadow.card.x,
                y: DS.Shadow.card.y
            )
    }
}

/// The reading surface — warm paper in light appearance, aubergine phosphor in dark.
///
/// Clips its content. Without that, a scrolling list draws into the rounded corners and
/// over the edge stroke, which is how the old build looked at the top and bottom of the
/// transcript page.
struct Page<Content: View>: View {
    var radius: CGFloat = DS.Radius.panel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(DS.Color.page)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(DS.Color.pageEdge, lineWidth: DS.Border.hairline)
            )
    }
}

/// A hairline rule. `onPage` picks the warmer paper rule over the chrome seam.
struct Rule: View {
    var onPage = false

    var body: some View {
        Rectangle()
            .fill(onPage ? DS.Color.pageRule : DS.Color.seam)
            .frame(height: DS.Border.hairline)
    }
}

// MARK: - Labels

/// A small editorial label — the kicker above a value or a section. Sentence case.
struct Eyebrow: View {
    let text: String
    var large = false
    var color: Color = DS.Color.inkLabel

    var body: some View {
        Text(text)
            .font(large ? DS.Font.eyebrowLarge : DS.Font.eyebrow)
            .tracking(DS.Font.eyebrowTracking)
            .foregroundStyle(color)
    }
}

/// Monospaced counter — clocks, word counts, timings.
struct Readout: View {
    let text: String
    var large = false
    var color: Color = DS.Color.inkOnPage

    var body: some View {
        Text(text)
            .font(large ? DS.Font.counterLarge : DS.Font.counter)
            .foregroundStyle(color)
    }
}

/// The push-to-talk key drawn as a physical key, so "hold this" is unmistakable.
struct KeyCap: View {
    let text: String
    var isLit = false

    var body: some View {
        Text(text)
            .font(DS.Font.labelEmphasis)
            .foregroundStyle(isLit ? DS.Color.copper : DS.Color.ink)
            .padding(.horizontal, DS.Space.snug)
            .padding(.vertical, DS.Space.hair)
            .background(
                isLit ? DS.Color.copperSoft : DS.Color.cap,
                in: .rect(cornerRadius: DS.Radius.chip)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip)
                    .strokeBorder(
                        isLit ? DS.Color.copper.opacity(DS.Color.Alpha.engagedEdge) : DS.Color.seam,
                        lineWidth: DS.Border.hairline
                    )
            )
    }
}

/// Status lamp. Red when recording; never used for anything else.
struct Lamp: View {
    let color: Color
    var isLit: Bool
    var size: CGFloat = DS.Size.lamp

    var body: some View {
        Circle()
            .fill(isLit ? color : color.opacity(DS.Color.Alpha.lampOff))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(color.opacity(DS.Color.Alpha.lampHalo), lineWidth: DS.Border.hairline)
                    .scaleEffect(1.6)
                    .opacity(isLit ? 1 : 0)
            )
            .animation(DS.Motion.lamp, value: isLit)
    }
}

// MARK: - Controls

/// The primary transport control. Red only while it is capturing.
struct RecordButton: View {
    let isCapturing: Bool
    let isBusy: Bool
    let action: () -> Void

    @State private var isHovering = false

    private var title: String {
        if isBusy { return "Working…" }
        return isCapturing ? "Stop" : "Record"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.snug) {
                Image(systemName: isCapturing ? "stop.fill" : "mic.fill")
                    .font(DS.Font.iconSmall)
                Text(title)
                    .font(DS.Font.labelEmphasis)
            }
            .foregroundStyle(isCapturing ? Color.white : DS.Color.ink)
            .frame(width: DS.Size.recordWidth, height: DS.Size.controlHeight)
            .background(face)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isBusy)
        .opacity(isBusy ? 0.5 : 1)
        .onHover { isHovering = $0 }
        .accessibilityLabel(isCapturing ? "Stop recording" : "Start recording")
        .help(isCapturing ? "Stop and transcribe" : "Record without holding the key")
    }

    private var face: some View {
        RoundedRectangle(cornerRadius: DS.Radius.control)
            .fill(isCapturing ? DS.Color.record : (isHovering ? DS.Color.capHover : DS.Color.cap))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.control)
                    .strokeBorder(
                        isCapturing ? DS.Color.record : DS.Color.seam,
                        lineWidth: DS.Border.hairline
                    )
            )
    }
}

/// A quiet chrome button. Engaged fill is copper unless the caller says otherwise.
struct PillButton: View {
    let title: String
    var systemImage: String?
    var isEngaged = false
    var accent: Color = DS.Color.copper
    var isEnabled = true
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.tight) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DS.Font.iconSmall)
                }
                Text(title)
                    .font(DS.Font.labelEmphasis)
            }
            .foregroundStyle(isEngaged ? accent : DS.Color.ink)
            .frame(minWidth: DS.Size.controlMinWidth)
            .frame(height: DS.Size.controlHeight)
            .padding(.horizontal, DS.Space.base)
            .background(face)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovering = $0 }
    }

    private var face: some View {
        RoundedRectangle(cornerRadius: DS.Radius.control)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.control)
                    .strokeBorder(
                        isEngaged ? accent.opacity(DS.Color.Alpha.engagedEdge) : DS.Color.seam,
                        lineWidth: DS.Border.hairline
                    )
            )
    }

    private var fill: Color {
        if isEngaged { return DS.Color.copperSoft }
        return isHovering && isEnabled ? DS.Color.capHover : DS.Color.cap
    }
}

/// A small, quiet action that lives *on the page* — row actions, footers, the Add button.
///
/// Always in the view tree, even when the row isn't hovered: it only fades. A control that
/// is conditionally built doesn't exist for VoiceOver or the keyboard at all.
struct PageButton: View {
    let title: String
    var systemImage: String?
    var isProminent = false
    var help: String?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.tight) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DS.Font.iconTiny)
                }
                if !title.isEmpty {
                    Text(title)
                        .font(DS.Font.eyebrow)
                        .tracking(DS.Font.eyebrowTracking)
                }
            }
            .foregroundStyle(isProminent || isHovering ? DS.Color.inkOnPage : DS.Color.inkOnPageMuted)
            .padding(.horizontal, DS.Space.snug)
            .padding(.vertical, DS.Space.tight)
            .background(
                isHovering ? DS.Color.pageRaised : Color.clear,
                in: .rect(cornerRadius: DS.Radius.chip)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip)
                    .strokeBorder(
                        isHovering ? DS.Color.pageEdge : DS.Color.pageRule,
                        lineWidth: DS.Border.hairline
                    )
            )
            .contentShape(.rect(cornerRadius: DS.Radius.chip))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help ?? title)
    }
}

/// A search field on the page. `⌘F` focuses it; Escape clears it.
struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var focus: Bool

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            Image(systemName: "magnifyingglass")
                .font(DS.Font.iconSmall)
                .foregroundStyle(focus ? DS.Color.copper : DS.Color.inkOnPageMuted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.inkOnPage)
                .focused($focus)
                .onExitCommand {
                    if text.isEmpty { focus = false } else { text = "" }
                }

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Color.inkOnPageFaint)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.snug)
        .background(DS.Color.page)
        .overlay(alignment: .bottom) { Rule(onPage: true) }
    }
}

// MARK: - Instrumentation

/// Voice as a scrolling bar meter.
///
/// The old meter drew a fixed-frequency sine whose amplitude tracked the level, which at
/// speaking volume read as a flat line. This keeps a short history of the level and draws
/// it as mirrored bars, so you can see the shape of what you just said.
///
/// The history and ballistics live in a plain reference type, not `@State`: mutating
/// SwiftUI state inside a `Canvas` draw closure is undefined and floods the log.
struct LevelMeter: View {
    let level: Float
    var isActive: Bool
    var onPage = false

    @State private var trace = Trace()

    private final class Trace {
        var samples: [Double]
        var smoothed: Double = 0
        var lastAdvance: TimeInterval = 0

        init() { samples = Array(repeating: 0, count: DS.Size.meterBars) }
    }

    /// One new bar every 45 ms — slow enough to read, fast enough to feel live.
    private static let sampleInterval: TimeInterval = 0.045

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, at: timeline.date)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, at date: Date) {
        advance(at: date.timeIntervalSinceReferenceDate)

        let count = trace.samples.count
        guard count > 0, size.width > 0 else { return }

        let slot = size.width / CGFloat(count)
        let barWidth = max(1.5, slot * 0.55)
        let midY = size.height / 2
        let maxHalf = size.height / 2 - 1
        let color = isActive
            ? DS.Color.violet
            : (onPage ? DS.Color.inkOnPageFaint : DS.Color.inkSecondary)

        // Idle: a single rule. Drawing 32 near-zero bars instead reads as a dotted line,
        // which looks like a rendering fault rather than a quiet microphone.
        guard isActive || trace.smoothed > 0.01 else {
            let rule = CGRect(x: 0, y: midY - 0.5, width: size.width, height: 1)
            context.fill(Path(rule), with: .color(color.opacity(DS.Color.Alpha.meterRest)))
            return
        }

        for (index, sample) in trace.samples.enumerated() {
            // Newest sample on the right.
            let x = slot * (CGFloat(index) + 0.5) - barWidth / 2
            let half = max(0.75, maxHalf * CGFloat(sample))
            let rect = CGRect(x: x, y: midY - half, width: barWidth, height: half * 2)
            let fade = 0.35 + 0.65 * Double(index) / Double(count - 1)
            context.fill(
                Path(roundedRect: rect, cornerRadius: barWidth / 2),
                with: .color(color.opacity(isActive ? fade : 0.5))
            )
        }
    }

    private func advance(at now: TimeInterval) {
        let target = isActive ? Double(min(max(level, 0.02), 1)) : 0
        // Fast attack, slow release, so a loud syllable spikes and then eases back.
        let rate = target > trace.smoothed ? DS.Motion.meterAttack : DS.Motion.meterRelease
        trace.smoothed += (target - trace.smoothed) * min(1, Self.sampleInterval / rate)

        guard now - trace.lastAdvance >= Self.sampleInterval else { return }
        trace.lastAdvance = now
        trace.samples.removeFirst()
        // Square-root the level: speech spends most of its time in the bottom of a linear
        // scale, so a linear meter barely moves.
        trace.samples.append(sqrt(max(0, trace.smoothed)))
    }
}

// MARK: - Press feedback

/// Plain button chrome plus a slight scale while held.
///
/// The style reads `configuration.isPressed` rather than layering an
/// `onLongPressGesture(minimumDuration: 0)` over the button, which is the usual way this
/// gets done and quietly competes with the button's own gesture.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(
                configuration.isPressed ? DS.Motion.press : DS.Motion.release,
                value: configuration.isPressed
            )
            .contentShape(.rect)
    }
}

// MARK: - Empty states

/// What a section shows when it has nothing to show.
///
/// Centred, with the reason and the way out. The old version was a small muted label pinned
/// to the top-left corner of a large empty page, which read as a rendering failure.
struct EmptyPage<Action: View>: View {
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: DS.Space.base) {
            Image(systemName: symbol)
                .font(DS.Font.glyph)
                .foregroundStyle(DS.Color.inkOnPageFaint)

            VStack(spacing: DS.Space.tight) {
                Text(title)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.inkOnPage)
                Text(detail)
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkOnPageMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
            }

            action
        }
        .padding(DS.Space.panel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EmptyPage where Action == EmptyView {
    init(symbol: String, title: String, detail: String) {
        self.init(symbol: symbol, title: title, detail: detail) { EmptyView() }
    }
}

/// A section heading on the page — the day a group of transcripts belongs to, or the name
/// of a block in the activity panel.
struct PageHeading: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            Eyebrow(text: title, color: DS.Color.inkOnPageStrong)
            if let trailing {
                Eyebrow(text: trailing, color: DS.Color.inkOnPageFaint)
            }
            Spacer(minLength: 0)
        }
    }
}
