import SwiftUI

struct HUDView: View {
    @Bindable var controller: DictationController

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            VUMeter(level: controller.level, isActive: controller.state == .listening)
                .frame(width: DS.Size.waveformWidth, height: DS.Size.waveformHeight)

            Text(label)
                .font(DS.Font.hud)
                .foregroundStyle(isError ? DS.Color.record : DS.Color.inkOnDeck)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(DS.Motion.release, value: controller.transcript)
        }
        .padding(.horizontal, DS.Space.snug)
        .padding(.vertical, DS.Space.tight)
        .frame(width: DS.Size.hudWidth, height: DS.Size.hudHeight)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.window, style: .continuous)
                .fill(DS.Color.deck)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.window, style: .continuous)
                        .strokeBorder(DS.Color.deckEdge, lineWidth: DS.Border.hairline)
                }
                .shadow(
                    color: DS.Shadow.phosphor.color,
                    radius: DS.Shadow.phosphor.radius,
                    x: DS.Shadow.phosphor.x,
                    y: DS.Shadow.phosphor.y
                )
        }
    }

    private var isError: Bool {
        if case .error = controller.state { return true }
        return false
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
