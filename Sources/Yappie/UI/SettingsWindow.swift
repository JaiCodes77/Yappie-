import SwiftUI

/// Settings — hotkey and model, per the brief. Opens on ⌘, via the standard `Settings` scene,
/// so the system wires up the menu item and the shortcut.
struct SettingsWindow: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared

    var body: some View {
        ZStack {
            DS.Color.chassis.ignoresSafeArea()

            VStack(alignment: .leading, spacing: DS.Space.wide) {
                panel(label: "Push to talk") {
                    HStack(spacing: DS.Space.snug) {
                        ForEach(PushToTalkKey.allCases, id: \.self) { key in
                            TransportKey(
                                title: key.displayName,
                                isEngaged: settings.pushToTalkKey == key,
                                engagedColor: DS.Color.copper
                            ) {
                                settings.pushToTalkKey = key
                                controller.reloadHotkey()
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    note("Hold this key anywhere to dictate. The window's Record button works "
                        + "regardless of what's focused.")
                }

                panel(label: "Model") {
                    HStack(spacing: DS.Space.snug) {
                        ForEach(SpeechEngineChoice.allCases, id: \.self) { choice in
                            TransportKey(
                                title: choice == .apple ? "Apple" : "Parakeet",
                                isEngaged: settings.engine == choice,
                                engagedColor: DS.Color.copper
                            ) {
                                settings.engine = choice
                            }
                        }
                    }
                    note(settings.engine == .apple
                        ? "Apple's on-device transcriber. Streams text while you speak; no download."
                        : "Parakeet on the Neural Engine. Resolves on release; ~470 MB model.")
                }

                panel(label: "Cleanup") {
                    Toggle(isOn: $settings.cleanupEnabled) {
                        Silkscreen(text: "Clean up transcripts")
                    }
                    .toggleStyle(.switch)
                    note("Strips fillers, fixes spacing and punctuation. The dictionary's "
                        + "corrections run either way.")
                }

                Spacer()
            }
            .padding(DS.Space.panel)
        }
        .frame(width: DS.Size.settingsWidth, height: DS.Size.settingsHeight)
    }

    private func panel<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.base) {
            Silkscreen(text: label, large: true)
            content()
        }
        .padding(DS.Space.roomy)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrushedPanel())
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(DS.Font.label)
            .foregroundStyle(DS.Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
