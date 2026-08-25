import SwiftUI

/// Settings — everything that changes how dictation behaves.
///
/// Compare mode, smart cleanup and the start/stop sound used to exist *only* as menu-bar
/// toggles, so opening Settings showed three of the six things you can actually change and
/// gave no hint the rest existed. The menu bar keeps them as quick toggles; this is the
/// complete surface.
struct SettingsWindow: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.roomy) {
                pushToTalk
                engine
                cleanup
                feedback
            }
            .padding(DS.Space.wide)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.Color.chassis)
        .frame(width: DS.Size.settingsWidth, height: DS.Size.settingsHeight)
    }

    private var pushToTalk: some View {
        SettingsSection("Push to talk", note: "The Record button in the window works regardless of what has focus.") {
            PushToTalkSetup(controller: controller)
        }
    }

    private var engine: some View {
        SettingsSection("Speech engine") {
            Choice(
                options: SpeechEngineChoice.allCases,
                selection: settings.engine,
                title: { $0 == .apple ? "Apple" : "Parakeet" },
                select: { settings.engine = $0 }
            )
            Note(settings.engine == .apple
                ? "Apple's on-device transcriber. Streams text while you speak; nothing to download."
                : "NVIDIA Parakeet on the Neural Engine. Resolves on release; needs a ~470 MB model.")

            if settings.engine == .parakeet {
                ParakeetModelRow()
            }

            Divider().overlay(DS.Color.seam)

            Toggle(isOn: $settings.compareMode) {
                Text("Compare every engine on each recording")
                    .font(DS.Font.label)
            }
            .toggleStyle(.switch)
            // The single most confusing behaviour in the app, so it says so here.
            Note("Runs all engines on one recording and shows them side by side in the "
                + "comparison window. **Nothing is typed into the focused app** in this mode — two "
                + "transcripts would fight over one text field.")
        }
    }

    private var cleanup: some View {
        SettingsSection("Cleanup") {
            Toggle(isOn: $settings.cleanupEnabled) {
                Text("Clean up transcripts before typing them")
                    .font(DS.Font.label)
            }
            .toggleStyle(.switch)
            Note("Strips fillers, applies spoken punctuation, capitalises sentences. Dictionary "
                + "corrections run either way.")

            if settings.cleanupEnabled {
                Divider().overlay(DS.Color.seam)

                Toggle(isOn: $settings.smartCleanup) {
                    Text("Use the on-device model")
                        .font(DS.Font.label)
                }
                .toggleStyle(.switch)
                .disabled(!FoundationModelFormatter.isAvailable)

                Note(FoundationModelFormatter.unavailableReason
                    ?? "Apple Intelligence handles tone, lists and spoken corrections like "
                    + "\"make that three, actually\". Falls back to the rule pass if it stalls. "
                    + "Nothing leaves the Mac.")
            }
        }
    }

    private var feedback: some View {
        SettingsSection("Feedback") {
            Toggle(isOn: $settings.soundEnabled) {
                Text("Play a tick when capture starts and stops")
                    .font(DS.Font.label)
            }
            .toggleStyle(.switch)
            Note("The floating HUD appears while you hold the key either way.")
        }
    }
}

// MARK: - Pieces

/// A titled block on the chassis.
private struct SettingsSection<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder var content: Content

    init(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.base) {
            Eyebrow(text: title, large: true)
            content
            if let note {
                Note(note)
            }
        }
        .padding(DS.Space.roomy)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.bar, in: .rect(cornerRadius: DS.Radius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.panel)
                .strokeBorder(DS.Color.seam, lineWidth: DS.Border.hairline)
        )
    }
}

/// Explanatory copy under a control. Markdown, so a phrase can be emphasised.
private struct Note: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(LocalizedStringKey(text))
            .font(DS.Font.label)
            .foregroundStyle(DS.Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row of mutually exclusive pills.
private struct Choice<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let select: (Option) -> Void

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            ForEach(options, id: \.self) { option in
                PillButton(title: title(option), isEngaged: option == selection) {
                    select(option)
                }
                .accessibilityAddTraits(option == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

/// Parakeet's model state, with the download offered deliberately.
///
/// Pulling ~470 MB on the first hold looks like a hang, so this lives next to the engine
/// choice that needs it rather than only in the menu bar.
private struct ParakeetModelRow: View {
    @State private var isLoading = false
    @State private var onDisk = ParakeetModels.isDownloaded
    @State private var failure: String?

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            Lamp(color: onDisk ? DS.Color.positive : DS.Color.caution, isLit: true, size: DS.Size.lampSmall)

            Text(label)
                .font(DS.Font.label)
                .foregroundStyle(failure == nil ? DS.Color.inkSecondary : DS.Color.record)

            Spacer(minLength: DS.Space.snug)

            if !onDisk {
                PillButton(
                    title: isLoading ? "Downloading…" : "Download",
                    isEngaged: !isLoading,
                    isEnabled: !isLoading
                ) { download() }
            }
        }
        .padding(DS.Space.snug)
        .background(DS.Color.cap, in: .rect(cornerRadius: DS.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip)
                .strokeBorder(DS.Color.seam, lineWidth: DS.Border.hairline)
        )
    }

    private var label: String {
        if let failure { return failure }
        if isLoading { return "Fetching the Parakeet model…" }
        return onDisk ? "Model installed" : "Model not downloaded yet"
    }

    private func download() {
        guard !isLoading else { return }
        isLoading = true
        failure = nil
        Task {
            do {
                _ = try await ParakeetModels.shared.manager()
                onDisk = ParakeetModels.isDownloaded
            } catch {
                failure = "Download failed: \(error.localizedDescription)"
                Log.speech.error("Parakeet preload failed: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
}
