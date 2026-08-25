import AppKit
import SwiftUI

@main
struct YappieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The main window. A `Window` rather than a `WindowGroup`: this app has one front
        // panel, and letting ⌘N spawn a second copy of it makes no sense.
        Window("Yappie", id: "main") {
            MainWindow(controller: delegate.controller)
        }
        .defaultSize(width: 900, height: 640)
        .windowResizability(.contentMinSize)
        // The window's own top bar *is* the title bar. Two stacked strips of chrome before
        // any content was the single biggest waste of vertical space in the old layout.
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            ViewCommands()
            DictionaryCommands()
        }

        // Fully qualified: this app has its own `Settings` type, which otherwise shadows
        // SwiftUI's settings scene.
        SwiftUI.Settings {
            SettingsWindow(controller: delegate.controller)
        }

        // Secondary: status and the hotkey while you're working in another app.
        MenuBarExtra {
            MenuContent(controller: delegate.controller)
        } label: {
            Image(systemName: delegate.controller.state.isActive ? "waveform.circle.fill" : "waveform")
        }

        Window("Engine comparison", id: "comparison") {
            ComparisonWindow(controller: delegate.controller)
        }
        .defaultSize(width: 660, height: 580)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DictationController()
    private var hud: HUDPanel?
    private var stateObservation: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A regular app: dock icon, app menu, standard windows. The HUD is still a
        // non-activating panel, so dictating into another app never steals its focus — that
        // property belongs to the panel, not to the activation policy.
        NSApp.setActivationPolicy(.regular)

        hud = HUDPanel(controller: controller)

        // No system prompt fired here on purpose. It fires on *every* launch until the
        // grant lands, throwing a modal over whatever you were doing, and it says less than
        // the banner the window now shows in place — which carries the same button.
        _ = controller.activate()

        // One timer for the whole app. Accessibility has no change notification, so it has
        // to be polled; it used to be polled from three places at once, two of which also
        // re-armed the hotkey independently.
        PermissionMonitor.shared.start { [weak self] in
            self?.tick()
        }

        // Write the dashboard up front so the menu item always opens something, even
        // before the first dictation.
        RunLog.regenerate()

        // Parakeet's models take ~20s to load from disk, and that cost lands on whichever
        // dictation touches them first — so the first hold after every launch would stall
        // with the HUD showing nothing. Warm them in the background instead, but only when
        // they're actually going to be used and are already downloaded.
        let willUseParakeet = Settings.shared.compareMode || Settings.shared.engine == .parakeet
        if willUseParakeet, ParakeetModels.isDownloaded {
            Task.detached(priority: .utility) {
                _ = try? await ParakeetModels.shared.manager()
            }
        }

        // Every `make install` relaunches the app and drops its windows. Restoring the
        // window when it was open last time keeps it from vanishing on each rebuild.
        if UserDefaults.standard.bool(forKey: "comparisonWindowOpen") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                Self.showComparisonWindow()
            }
        }

        observeState()
        Log.app.info("Yappie ready — hold \(Settings.shared.pushToTalkKey.displayName) to dictate")
    }

    /// Runs once a second, off the permission monitor's timer.
    private func tick() {
        // Re-arm the moment a grant lands. Nothing else in the app re-arms on a timer.
        if !controller.hotkeyArmed,
           !controller.isBindingHotkey,
           PermissionMonitor.shared.hasAccessibility,
           controller.activate() {
            Log.app.info("Accessibility granted — hotkey armed")
        }
        // "Today" moves at midnight even if nothing is dictated.
        RunStore.shared.refreshLedgerIfDayChanged()
    }

    /// `yappie://clear` and `yappie://show`, used by the legacy HTML dashboard and
    /// as a scriptable way to raise the window.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "yappie" {
            switch url.host {
            case "clear":
                RunLog.clear()
                RunStore.shared.reload()
            case "show":
                Self.showComparisonWindow()
            default:
                break
            }
        }
    }

    /// Raises the comparison window without needing SwiftUI's `openWindow` environment
    /// value — usable from the app delegate and from a URL handler.
    static func showComparisonWindow() {
        RunStore.shared.reload()
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == "comparison" })
            ?? NSApp.windows.first(where: { $0.title == "Engine comparison" }) {
            existing.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        let isOpen = NSApp.windows.contains { $0.title == "Engine comparison" && $0.isVisible }
        UserDefaults.standard.set(isOpen, forKey: "comparisonWindowOpen")
        PermissionMonitor.shared.stop()
        controller.deactivate()
    }

    /// Shows and hides the HUD in step with the controller's state.
    private func observeState() {
        withObservationTracking {
            _ = controller.state
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.controller.state.isActive {
                    self.hud?.present()
                } else {
                    self.hud?.dismiss()
                }
                self.observeState()
            }
        }
    }
}

/// ⌘1 / ⌘2 / ⌘3 and ⌘F, as real menu items.
///
/// A keyboard shortcut on a hidden button works but is undiscoverable; the point of a menu
/// is that it tells you the shortcut exists.
private struct ViewCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            ForEach(WorkspaceSection.allCases) { section in
                Button(section.title) {
                    openWindow(id: "main")
                    Navigation.shared.show(section)
                }
                .keyboardShortcut(section.shortcut, modifiers: .command)
            }

            Divider()

            Button("Find…") {
                openWindow(id: "main")
                Navigation.shared.focusSearch()
            }
            .keyboardShortcut("f", modifiers: .command)

            Divider()
        }
    }
}

private struct DictionaryCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Add Dictionary Word…") {
                DictionaryStore.shared.beginAdd()
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button("Reveal Dictionary File") {
                NSWorkspace.shared.activateFileViewerSelecting([DictionaryStore.fileURL])
            }
        }
    }
}

/// The menu bar: state, the hold key, and the toggles worth flipping mid-task. Everything
/// here also lives in Settings, which is the complete surface.
private struct MenuContent: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared
    @State private var permissions = PermissionMonitor.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(controller.hotkeyArmed
             ? "Hold \(settings.pushToTalkKey.displayName) to dictate"
             : "Push-to-talk is not armed — grant Accessibility for Yappie")

        Divider()

        Picker("Push-to-talk key", selection: Binding(
            get: { settings.pushToTalkKey },
            set: { key in
                settings.pushToTalkKey = key
                controller.reloadHotkey()
            }
        )) {
            ForEach(PushToTalkKey.allCases, id: \.self) { key in
                Text(key.displayName).tag(key)
            }
        }
        .disabled(controller.isBindingHotkey)

        if !settings.compareMode {
            Picker("Engine", selection: $settings.engine) {
                ForEach(SpeechEngineChoice.allCases, id: \.self) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
        }

        Toggle("Compare mode (every engine)", isOn: $settings.compareMode)
        Toggle("Clean up text", isOn: $settings.cleanupEnabled)
        Toggle("Sound", isOn: $settings.soundEnabled)

        Divider()

        Button("Open Yappie") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Add dictionary word…") {
            DictionaryStore.shared.beginAdd()
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Engine comparison") {
            RunStore.shared.reload()
            openWindow(id: "comparison")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("d")

        if !controller.hotkeyArmed {
            Button("Grant Accessibility…") {
                Permissions.promptForAccessibility()
                Permissions.openAccessibilitySettings()
            }
        }
        if !permissions.hasMicrophone {
            Button("Grant Microphone…") { Permissions.openMicrophoneSettings() }
        }

        Divider()

        Button("Quit Yappie") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
