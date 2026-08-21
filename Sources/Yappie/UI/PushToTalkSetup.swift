import SwiftUI

/// Push-to-talk setup: current key, press-to-bind, picker fallback, and a loud
/// Accessibility grant when the tap is not armed. Lives on the main window so
/// the hold key is not buried in Settings or the menu bar.
struct PushToTalkSetup: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared
    @State private var binder = PushToTalkBinder()
    @State private var isListening = false
    @State private var hint: String?
    @State private var accessibilityTrusted = Permissions.hasAccessibility

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.base) {
            currentKeyRow
            bindRow
            picker
            if let hint {
                Text(hint)
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !isListening, !controller.hotkeyArmed {
                accessibilityBanner
            }
        }
        .task { await pollArming() }
        .task(id: isListening) { await listenTimeout() }
        .onDisappear { abandonBindIfNeeded() }
    }

    private var currentKeyRow: some View {
        HStack(spacing: DS.Space.snug) {
            Lamp(
                color: controller.hotkeyArmed ? DS.Color.copper : DS.Color.inkSecondary,
                isLit: controller.hotkeyArmed
            )
            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Silkscreen(text: controller.hotkeyArmed ? "Armed" : "Not armed")
                Text(isListening
                     ? "Press the key you want to hold…"
                     : "Hold \(settings.pushToTalkKey.displayName) anywhere to dictate")
                    .font(DS.Font.label)
                    .foregroundStyle(isListening ? DS.Color.copper : DS.Color.ink)
            }
            Spacer()
        }
    }

    private var bindRow: some View {
        HStack(spacing: DS.Space.snug) {
            TransportKey(
                title: isListening ? "Listening…" : "Set push-to-talk key",
                isEngaged: isListening,
                engagedColor: DS.Color.copper
            ) {
                if isListening {
                    cancelBind()
                } else {
                    startBind()
                }
            }

            if isListening {
                TransportKey(
                    title: "Cancel",
                    engagedColor: DS.Color.copper
                ) {
                    cancelBind()
                }
            }
        }
    }

    private var picker: some View {
        HStack(spacing: DS.Space.snug) {
            ForEach(PushToTalkKey.allCases, id: \.self) { key in
                TransportKey(
                    title: key.displayName,
                    isEngaged: settings.pushToTalkKey == key && !isListening,
                    engagedColor: DS.Color.copper,
                    isEnabled: !controller.isBindingHotkey
                ) {
                    settings.pushToTalkKey = key
                    hint = nil
                    _ = controller.reloadHotkey()
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilityBanner: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            Silkscreen(text: "Accessibility is required", color: DS.Color.copper)
            Text(accessibilityCopy)
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if accessibilityTrusted {
                TransportKey(title: "Try again") {
                    _ = controller.reloadHotkey()
                }
            }
            TransportKey(
                title: accessibilityTrusted ? "Open Accessibility" : "Grant Accessibility",
                isEngaged: true,
                engagedColor: DS.Color.copper
            ) {
                Permissions.promptForAccessibility()
                Permissions.openAccessibilitySettings()
            }
        }
        .padding(DS.Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.control)
                .fill(DS.Color.copperSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.control)
                .strokeBorder(DS.Color.copper.opacity(0.55), lineWidth: DS.Border.hairline)
        )
    }

    private var accessibilityCopy: String {
        if accessibilityTrusted {
            return "macOS lists Accessibility as on, but the hold-key tap did not install. Turn Yappie off and on again in System Settings ▸ Privacy & Security ▸ Accessibility — a rebuilt app can leave a stale grant."
        }
        return "The hold key will not work until Accessibility is on for Yappie. Enable it in System Settings, then come back — the tap arms itself."
    }

    private func startBind() {
        hint = nil
        guard controller.beginHotkeyBind() else {
            hint = "Finish setting the push-to-talk key in the other window first."
            return
        }
        isListening = true
        binder.start { outcome in
            switch outcome {
            case .picked(let key):
                settings.pushToTalkKey = key
                isListening = false
                hint = "Hold \(key.displayName) anywhere to dictate."
                controller.finishHotkeyBind()
            case .rejectedLeftCommand:
                hint = "Left ⌘ can't be a hold key — it would break Copy, Paste, and Quit. Try Left ⌥, Right ⌥, fn, or Right ⌘."
            }
        }
    }

    private func cancelBind(leavingHint hintText: String? = nil) {
        binder.stop()
        isListening = false
        hint = hintText
        controller.finishHotkeyBind()
    }

    private func abandonBindIfNeeded() {
        guard isListening else { return }
        binder.stop()
        isListening = false
        controller.finishHotkeyBind()
    }

    private func pollArming() async {
        while !Task.isCancelled {
            accessibilityTrusted = Permissions.hasAccessibility
            if !controller.isBindingHotkey,
               !controller.hotkeyArmed,
               accessibilityTrusted {
                _ = controller.reloadHotkey()
            }
            try? await Task.sleep(for: .seconds(DS.Motion.permissionPoll))
        }
    }

    private func listenTimeout() async {
        guard isListening else { return }
        try? await Task.sleep(for: .seconds(DS.Motion.bindListen))
        guard !Task.isCancelled, isListening else { return }
        cancelBind(leavingHint: "No key caught — try again, or pick one below.")
    }
}
