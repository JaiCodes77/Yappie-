import YappieActivity
import YappieDictionary
import AppKit
import SwiftUI

/// The app's main window.
///
/// One bar of chrome across the top — it *is* the title bar, which is hidden — and below it
/// the page, where spoken words land. Three sections share the page: transcriptions, the
/// dictionary, and activity.
struct MainWindow: View {
    @Bindable var controller: DictationController
    @State private var store = DictionaryStore.shared
    @State private var runs = RunStore.shared
    @State private var navigation = Navigation.shared

    var body: some View {
        VStack(spacing: 0) {
            TopBar(controller: controller)
            Rule()

            VStack(spacing: DS.Space.base) {
                if !controller.hotkeyArmed {
                    AccessibilityBanner(controller: controller)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Page {
                    VStack(spacing: 0) {
                        SectionTabs(
                            section: Binding(
                                get: { navigation.section },
                                set: { navigation.section = $0 }
                            ),
                            ledger: runs.ledger
                        )
                        Rule(onPage: true)

                        switch navigation.section {
                        case .transcriptions: TranscriptionsPanel()
                        case .dictionary: DictionaryPanel()
                        case .activity: ActivityPanel()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(DS.Space.base)
        }
        .background(DS.Color.chassis)
        // The hidden title bar still reserves its safe area, which left a blank strip above
        // the top bar with the traffic lights floating in it. Ignoring it lets the bar *be*
        // the title bar, with the lights sitting in its leading gutter.
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: DS.Size.mainMinWidth, minHeight: DS.Size.mainMinHeight)
        .onChange(of: store.editorRequest?.id) { _, id in
            // Adding a word from the menu bar or ⌘⇧L should land you where the word will be.
            if id != nil { navigation.section = .dictionary }
        }
        .sheet(item: Binding(
            get: { store.editorRequest },
            set: { store.editorRequest = $0 }
        )) { request in
            DictionaryEditor(request: request) { entry in
                store.saveFromEditor(entry, request: request)
                navigation.section = .dictionary
            }
        }
    }
}

// MARK: - Top bar

/// Transport, level, clock and status in one strip that doubles as the title bar.
///
/// The old bar carried a Record button, a separate "Rec" lamp and label, a divider, the
/// meter, the clock, a two-line status block pinned to a fixed 190pt, and the key menu —
/// about 740pt of content in a window whose minimum was 720. It clipped. This says each
/// thing once and lets the status line be the part that gives.
private struct TopBar: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared

    @State private var elapsed: TimeInterval = 0
    @State private var startedAt: Date?

    private var isCapturing: Bool {
        controller.state == .starting || controller.state == .listening
    }

    private var isFinishing: Bool { controller.state == .finishing }

    var body: some View {
        HStack(spacing: DS.Space.base) {
            RecordButton(isCapturing: isCapturing, isBusy: isFinishing) {
                if isCapturing {
                    controller.stopButtonRecording()
                } else {
                    controller.startButtonRecording()
                }
            }

            instrument

            Spacer(minLength: DS.Space.snug)

            status

            holdKey
        }
        // The traffic lights float over the content once the title bar is hidden.
        .padding(.leading, DS.Size.trafficLights)
        .padding(.trailing, DS.Space.base)
        .frame(height: DS.Size.topBar)
        .background(DS.Color.bar)
        .onChange(of: controller.state.isActive) { _, active in
            startedAt = active ? Date() : nil
            if !active { elapsed = 0 }
        }
        .task(id: startedAt) {
            guard let startedAt else { return }
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(startedAt)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    /// Meter and clock share one recessed field, so they read as one instrument rather
    /// than two unrelated widgets.
    private var instrument: some View {
        HStack(spacing: DS.Space.snug) {
            LevelMeter(level: controller.level, isActive: isCapturing, onPage: true)
                .frame(width: DS.Size.meterWidth, height: DS.Size.meterHeight)

            Readout(
                text: counterText,
                color: isCapturing ? DS.Color.record : DS.Color.inkOnPageMuted
            )
        }
        .padding(.horizontal, DS.Space.snug)
        .padding(.vertical, DS.Space.tight)
        .background(DS.Color.page, in: .rect(cornerRadius: DS.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.control)
                .strokeBorder(
                    isCapturing ? DS.Color.record.opacity(DS.Color.Alpha.meterRest) : DS.Color.pageEdge,
                    lineWidth: DS.Border.hairline
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCapturing ? "Recording, \(counterText)" : "Level meter, idle")
    }

    /// One line, free to truncate. It's the only thing here whose width isn't essential.
    private var status: some View {
        HStack(spacing: DS.Space.snug) {
            Lamp(color: statusColor, isLit: statusIsLit)
            Text(statusText)
                .font(DS.Font.label)
                .foregroundStyle(isError ? DS.Color.record : DS.Color.inkSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .animation(DS.Motion.release, value: statusText)
        }
        .help(statusText)
        .layoutPriority(-1)
    }

    /// Which key to hold, stated — not a third place to change it.
    ///
    /// The bar used to carry a full key picker, duplicating the one in Settings and the one
    /// in the menu bar. What you actually need here is the answer to "which key is it
    /// again?", so this shows the key and opens Settings if you want to change it.
    private var holdKey: some View {
        SettingsLink {
            HStack(spacing: DS.Space.tight) {
                Eyebrow(text: "Hold", color: DS.Color.inkSecondary)
                KeyCap(text: settings.pushToTalkKey.displayName, isLit: isCapturing)
            }
            .fixedSize()
        }
        .buttonStyle(PressableButtonStyle())
        .help("Which key to hold while you talk — click to change it in Settings")
    }

    private var isError: Bool {
        if case .error = controller.state { return true }
        return false
    }

    private var statusText: String {
        switch controller.state {
        case .starting, .listening:
            "Listening — release \(settings.pushToTalkKey.displayName)"
        case .finishing:
            controller.transcript.isEmpty ? "Transcribing…" : controller.transcript
        case .error(let message):
            message
        case .idle:
            controller.hotkeyArmed ? "Ready" : "Accessibility needed"
        }
    }

    private var statusColor: Color {
        switch controller.state {
        case .starting, .listening: DS.Color.record
        case .finishing: DS.Color.copper
        case .error: DS.Color.record
        case .idle: controller.hotkeyArmed ? DS.Color.positive : DS.Color.inkSecondary
        }
    }

    private var statusIsLit: Bool {
        controller.state != .idle || controller.hotkeyArmed
    }

    private var counterText: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - Section tabs

private struct SectionTabs: View {
    @Binding var section: WorkspaceSection
    let ledger: ActivityLedger

    var body: some View {
        HStack(spacing: DS.Space.hair) {
            ForEach(WorkspaceSection.allCases) { candidate in
                Tab(candidate: candidate, isSelected: candidate == section) {
                    withAnimation(DS.Motion.panel) { section = candidate }
                }
            }

            Spacer(minLength: DS.Space.base)

            ActivitySummary(ledger: ledger)
        }
        .padding(.horizontal, DS.Space.snug)
        .padding(.vertical, DS.Space.snug)
    }

    private struct Tab: View {
        let candidate: WorkspaceSection
        let isSelected: Bool
        let action: () -> Void

        @State private var isHovering = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: DS.Space.tight) {
                    Image(systemName: candidate.symbol)
                        .font(DS.Font.iconTiny)
                    Text(candidate.title)
                        .font(DS.Font.eyebrow)
                        .tracking(DS.Font.eyebrowTracking)
                }
                .foregroundStyle(isSelected ? DS.Color.copper : DS.Color.inkOnPageMuted)
                .padding(.horizontal, DS.Space.base)
                .padding(.vertical, DS.Space.snug)
                .background(background)
                .contentShape(.rect(cornerRadius: DS.Radius.chip))
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }

        private var background: some View {
            RoundedRectangle(cornerRadius: DS.Radius.chip)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(
                            isSelected ? DS.Color.copper.opacity(DS.Color.Alpha.edge) : Color.clear,
                            lineWidth: DS.Border.hairline
                        )
                )
        }

        private var fill: Color {
            if isSelected { return DS.Color.copperSoft }
            return isHovering ? DS.Color.pageHover : .clear
        }
    }
}

/// Today's words and the streak, visible on every tab so the number you care about isn't
/// hidden behind a tab you have to remember to visit.
private struct ActivitySummary: View {
    let ledger: ActivityLedger

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            figure(ledger.wordsToday.formatted(), "words today")
            Rectangle()
                .fill(DS.Color.pageRule)
                .frame(width: DS.Border.hairline, height: DS.Space.base)
            figure(ledger.currentStreak == 0 ? "—" : "\(ledger.currentStreak)", "day streak")
        }
        .padding(.trailing, DS.Space.tight)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        HStack(spacing: DS.Space.tight) {
            Readout(text: value)
            Eyebrow(text: label, color: DS.Color.inkOnPageFaint)
        }
    }

    private var accessibility: String {
        let today = "\(ledger.wordsToday.formatted()) words today"
        if ledger.currentStreak == 0 { return "\(today), no streak" }
        let days = ledger.currentStreak == 1 ? "1 day streak" : "\(ledger.currentStreak) day streak"
        return "\(today), \(days)"
    }
}

// MARK: - Accessibility banner

/// The permission failure, stated once. `PushToTalkSetup` in Settings used to carry its own
/// near-identical copy of this; both now come from here.
struct AccessibilityBanner: View {
    @Bindable var controller: DictationController
    @State private var permissions = PermissionMonitor.shared

    /// `AXIsProcessTrusted` is true but the tap still failed: the signature changed and the
    /// stored TCC requirement no longer matches, so the grant has to be re-made.
    private var isStaleGrant: Bool { permissions.hasAccessibility }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.base) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Font.iconSmall)
                .foregroundStyle(DS.Color.caution)
                .padding(.top, DS.Space.hair)

            VStack(alignment: .leading, spacing: DS.Space.tight) {
                Text(title)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)
                Text(detail)
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DS.Space.snug) {
                    PillButton(
                        title: isStaleGrant ? "Open Accessibility" : "Grant access",
                        isEngaged: true
                    ) {
                        Permissions.promptForAccessibility()
                        Permissions.openAccessibilitySettings()
                    }
                    PillButton(title: "Try again") {
                        permissions.refresh()
                        _ = controller.reloadHotkey()
                    }
                }
                .padding(.top, DS.Space.tight)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Space.roomy)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.copperSoft, in: .rect(cornerRadius: DS.Radius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.panel)
                .strokeBorder(DS.Color.caution.opacity(DS.Color.Alpha.meterRest), lineWidth: DS.Border.hairline)
        )
    }

    private var title: String {
        isStaleGrant ? "Accessibility needs refreshing" : "Yappie needs Accessibility"
    }

    private var detail: String {
        if isStaleGrant {
            return "macOS lists Accessibility as on, but the grant belongs to an older build. "
                + "Remove Yappie in Privacy & Security ▸ Accessibility, add /Applications/Yappie.app "
                + "again, then switch it on."
        }
        // Being listed with the switch off is the usual failure mode after "Grant access" —
        // the OS adds the row but leaves the toggle grey. Say that explicitly.
        return "Being listed isn’t enough. In Privacy & Security ▸ Accessibility, find Yappie "
            + "and flip its switch ON (blue). Then click Try again — the hold key arms itself."
    }
}
