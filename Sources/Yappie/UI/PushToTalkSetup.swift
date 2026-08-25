import SwiftUI

/// Push-to-talk setup: which key, press-to-bind, and a picker fallback.
///
/// It no longer polls Accessibility on its own timer or carry its own copy of the grant
/// banner — `PermissionMonitor` does the polling for the whole app, and the banner is
/// `AccessibilityBanner`, so the two can't disagree about whether the tap is armed.
struct PushToTalkSetup: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared
    @State private var binder = PushToTalkBinder()
    @State private var isListening = false
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.base) {
            currentKey
            keyChoices
            bindRow

            if let hint {
                Text(hint)
                    .font(DS.Font.label)
                    .foregroundStyle(isListening ? DS.Color.copper : DS.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isListening, !controller.hotkeyArmed {
                AccessibilityBanner(controller: controller)
            }
        }
        .task(id: isListening) { await listenTimeout() }
        .onDisappear { abandonBindIfNeeded() }
    }

    private var currentKey: some View {
        HStack(spacing: DS.Space.snug) {
            Lamp(
                color: controller.hotkeyArmed ? DS.Color.positive : DS.Color.inkSecondary,
                isLit: controller.hotkeyArmed
            )
            Text(isListening ? "Press the key you want to hold…" : "Hold")
                .font(DS.Font.label)
                .foregroundStyle(isListening ? DS.Color.copper : DS.Color.inkSecondary)
            if !isListening {
                KeyCap(text: settings.pushToTalkKey.displayName, isLit: true)
                Text("anywhere to dictate")
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkSecondary)
            }
            Spacer(minLength: 0)
            Eyebrow(
                text: controller.hotkeyArmed ? "Armed" : "Not armed",
                color: controller.hotkeyArmed ? DS.Color.positive : DS.Color.inkSecondary
            )
        }
    }

    private var keyChoices: some View {
        HStack(spacing: DS.Space.snug) {
            ForEach(PushToTalkKey.allCases, id: \.self) { key in
                PillButton(
                    title: key.displayName,
                    isEngaged: settings.pushToTalkKey == key && !isListening,
                    isEnabled: !controller.isBindingHotkey
                ) {
                    settings.pushToTalkKey = key
                    hint = nil
                    _ = controller.reloadHotkey()
                }
                .accessibilityAddTraits(
                    settings.pushToTalkKey == key ? [.isButton, .isSelected] : .isButton
                )
            }
            Spacer(minLength: 0)
        }
    }

    private var bindRow: some View {
        HStack(spacing: DS.Space.snug) {
            PillButton(
                title: isListening ? "Listening for a key…" : "Press a key instead",
                systemImage: isListening ? "dot.radiowaves.left.and.right" : "keyboard",
                isEngaged: isListening
            ) {
                if isListening { cancelBind() } else { startBind() }
            }

            if isListening {
                PillButton(title: "Cancel") { cancelBind() }
            }
            Spacer(minLength: 0)
        }
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
                hint = "Left ⌘ can't be a hold key — it would break Copy, Paste, and Quit. "
                    + "Try Left ⌥, Right ⌥, fn, or Right ⌘."
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

    private func listenTimeout() async {
        guard isListening else { return }
        try? await Task.sleep(for: .seconds(DS.Motion.bindListen))
        guard !Task.isCancelled, isListening else { return }
        cancelBind(leavingHint: "No key caught — try again, or pick one above.")
    }
}
