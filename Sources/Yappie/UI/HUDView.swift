import SwiftUI

/// The floating capsule shown while you hold the key.
///
/// It has to be readable in a quarter-second glance over whatever app you're dictating
/// into, so: a state lamp, the level, and the words. The words are the wide part, and they
/// truncate from the head — what you just said matters more than how you started.
struct HUDView: View {
    @Bindable var controller: DictationController

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            Lamp(color: lampColor, isLit: true)

            LevelMeter(level: controller.level, isActive: isListening, onPage: true)
                .frame(width: DS.Size.hudMeterWidth, height: DS.Size.hudMeterHeight)

            Text(label)
                .font(DS.Font.hud)
                .foregroundStyle(isError ? DS.Color.record : DS.Color.inkOnPage)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(DS.Motion.release, value: controller.transcript)
        }
        .padding(.horizontal, DS.Space.base)
        .frame(width: DS.Size.hudWidth, height: DS.Size.hudHeight)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.window, style: .continuous)
                .fill(DS.Color.page)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.window, style: .continuous)
                        .strokeBorder(edgeColor, lineWidth: DS.Border.hairline)
                }
                .shadow(
                    color: DS.Shadow.hud.color,
                    radius: DS.Shadow.hud.radius,
                    x: DS.Shadow.hud.x,
                    y: DS.Shadow.hud.y
                )
        }
    }

    private var isListening: Bool {
        controller.state == .starting || controller.state == .listening
    }

    private var isError: Bool {
        if case .error = controller.state { return true }
        return false
    }

    private var lampColor: Color {
        if isError { return DS.Color.record }
        return isListening ? DS.Color.record : DS.Color.copper
    }

    /// Red while capturing, so the HUD reads as "live mic" from the corner of your eye.
    private var edgeColor: Color {
        if isError { return DS.Color.record.opacity(DS.Color.Alpha.selectedEdge) }
        return isListening ? DS.Color.record.opacity(DS.Color.Alpha.meterRest) : DS.Color.pageEdge
    }

    private var label: String {
        switch controller.state {
        case .starting: "Listening…"
        case .listening: controller.transcript.isEmpty ? "Listening…" : controller.transcript
        case .finishing: controller.transcript.isEmpty ? "Transcribing…" : controller.transcript
        case .error(let message): message
        case .idle: ""
        }
    }
}
