import YappieDictionary
import AppKit
import SwiftUI

/// The app's main window.
///
/// A compact control bar above the amber phosphor page holding transcripts or the
/// dictionary. The page is the product: that's where spoken words land.
struct MainWindow: View {
    @Bindable var controller: DictationController
    @State private var store = DictionaryStore.shared

    @State private var section: Section = .transcriptions

    enum Section: String, CaseIterable, Identifiable {
        case transcriptions
        case dictionary

        var id: String { rawValue }
        var title: String { self == .transcriptions ? "Transcriptions" : "Dictionary" }
    }

    var body: some View {
        ZStack {
            DS.Color.chassis.ignoresSafeArea()

            VStack(spacing: DS.Space.base) {
                ControlBar(controller: controller)

                if !controller.hotkeyArmed {
                    AccessibilityStrip(controller: controller)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Well {
                    VStack(spacing: 0) {
                        pageHeader

                        Group {
                            switch section {
                            case .transcriptions: TranscriptionList()
                            case .dictionary: DictionaryPanel()
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .layoutPriority(1)
            }
            .padding(DS.Space.roomy)
        }
        .frame(minWidth: DS.Size.mainMinWidth, minHeight: DS.Size.mainMinHeight)
        .sheet(item: Binding(
            get: { store.editorRequest },
            set: { store.editorRequest = $0 }
        )) { request in
            DictionaryEditor(request: request) { entry in
                store.saveFromEditor(entry, request: request)
                section = .dictionary
            }
        }
    }

    private var pageHeader: some View {
        HStack(spacing: DS.Space.tight) {
            ForEach(Section.allCases) { candidate in
                Button {
                    withAnimation(DS.Motion.panel) { section = candidate }
                } label: {
                    Silkscreen(
                        text: candidate.title,
                        color: section == candidate ? DS.Color.inkOnDeck : DS.Color.inkOnDeckMuted
                    )
                    .padding(.horizontal, DS.Space.base)
                    .padding(.vertical, DS.Space.snug)
                    .background(
                        section == candidate ? DS.Color.copperSoft : Color.clear,
                        in: .rect(cornerRadius: DS.Radius.chip)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.snug)
        .padding(.vertical, DS.Space.tight)
        .background(DS.Color.deck)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.Color.deckHairline)
                .frame(height: DS.Border.seam)
        }
    }
}

// MARK: - Control bar

/// Recording and push-to-talk share one status surface, so the same activity never reads
/// as "idle" in one place and "listening" in another.
private struct ControlBar: View {
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
            TransportKey(
                title: recordButtonTitle,
                systemImage: isCapturing ? "stop.fill" : "circle.fill",
                isEngaged: isCapturing,
                isEnabled: !isFinishing
            ) {
                if isCapturing {
                    controller.stopButtonRecording()
                } else {
                    controller.startButtonRecording()
                }
            }

            HStack(spacing: DS.Space.tight) {
                Lamp(color: DS.Color.record, isLit: isCapturing)
                Silkscreen(text: "Rec")
            }

            divider

            VUMeter(level: controller.level, isActive: isCapturing)
                .frame(width: DS.Size.toolbarMeterWidth, height: DS.Size.toolbarMeterHeight)

            DeckWindow {
                Readout(text: counterText)
                    .padding(.horizontal, DS.Space.snug)
                    .padding(.vertical, DS.Space.tight)
            }

            Spacer(minLength: DS.Space.base)

            HStack(spacing: DS.Space.snug) {
                Lamp(color: statusColor, isLit: statusIsLit)

                VStack(alignment: .leading, spacing: DS.Space.hair) {
                    Silkscreen(text: statusTitle)
                    Text(statusDetail)
                        .font(DS.Font.label)
                        .foregroundStyle(DS.Color.inkSecondary)
                        .lineLimit(1)
                        .frame(width: DS.Size.statusCopyWidth, alignment: .leading)
                }

                Menu {
                    ForEach(PushToTalkKey.allCases, id: \.self) { key in
                        Button {
                            settings.pushToTalkKey = key
                            _ = controller.reloadHotkey()
                        } label: {
                            if settings.pushToTalkKey == key {
                                Label(key.displayName, systemImage: "checkmark")
                            } else {
                                Text(key.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: DS.Space.tight) {
                        Silkscreen(text: settings.pushToTalkKey.displayName)
                        Image(systemName: "chevron.down")
                            .font(DS.Font.iconTiny)
                            .foregroundStyle(DS.Color.inkSecondary)
                    }
                    .frame(height: DS.Material.keyHeight)
                    .padding(.horizontal, DS.Space.base)
                    .background(DS.Color.cap, in: .rect(cornerRadius: DS.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.control)
                            .strokeBorder(DS.Color.seam, lineWidth: DS.Border.hairline)
                    )
                }
                .menuStyle(.borderlessButton)
                .disabled(controller.isBindingHotkey)
            }
        }
        .padding(DS.Space.base)
        .background(BrushedPanel())
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

    private var divider: some View {
        Rectangle()
            .fill(DS.Color.seam)
            .frame(width: DS.Border.seam, height: DS.Size.toolbarDividerHeight)
    }

    private var recordButtonTitle: String {
        if isFinishing { return "Finishing…" }
        return isCapturing ? "Stop" : "Record"
    }

    private var statusTitle: String {
        switch controller.state {
        case .starting, .listening: "Listening"
        case .finishing: "Transcribing"
        case .error: "Needs attention"
        case .idle: controller.hotkeyArmed ? "Ready" : "Not ready"
        }
    }

    private var statusDetail: String {
        switch controller.state {
        case .starting, .listening:
            "Release \(settings.pushToTalkKey.displayName) to finish"
        case .finishing:
            controller.transcript.isEmpty ? "Cleaning up your words…" : controller.transcript
        case .error(let message):
            message
        case .idle:
            controller.hotkeyArmed
                ? "Hold \(settings.pushToTalkKey.displayName) anywhere"
                : "Accessibility needs attention"
        }
    }

    private var statusColor: Color {
        switch controller.state {
        case .starting, .listening: DS.Color.record
        case .finishing, .error: DS.Color.copper
        case .idle: controller.hotkeyArmed ? DS.Color.meterGreen : DS.Color.inkSecondary
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

/// The permission failure stays actionable without consuming half the window. When
/// `AXIsProcessTrusted` is true but the tap still fails, the signed build changed and the
/// old TCC row must be refreshed.
private struct AccessibilityStrip: View {
    @Bindable var controller: DictationController
    @State private var accessibilityTrusted = Permissions.hasAccessibility

    var body: some View {
        HStack(spacing: DS.Space.base) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Font.iconSmall)
                .foregroundStyle(DS.Color.copper)

            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Silkscreen(text: title, color: DS.Color.copper)
                Text(detail)
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: DS.Space.base)

            TransportKey(title: "Try again") {
                accessibilityTrusted = Permissions.hasAccessibility
                _ = controller.reloadHotkey()
            }

            TransportKey(
                title: accessibilityTrusted ? "Open Accessibility" : "Grant access",
                isEngaged: true,
                engagedColor: DS.Color.copper
            ) {
                Permissions.promptForAccessibility()
                Permissions.openAccessibilitySettings()
            }
        }
        .padding(DS.Space.base)
        .background(DS.Color.copperSoft, in: .rect(cornerRadius: DS.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.control)
                .strokeBorder(DS.Color.deckEdge, lineWidth: DS.Border.hairline)
        )
        .task {
            while !Task.isCancelled {
                accessibilityTrusted = Permissions.hasAccessibility
                try? await Task.sleep(for: .seconds(DS.Motion.permissionPoll))
            }
        }
    }

    private var title: String {
        accessibilityTrusted ? "Refresh Accessibility access" : "Allow Accessibility access"
    }

    private var detail: String {
        if accessibilityTrusted {
            return "macOS still has a grant for an older Yappie build. Remove Yappie in Accessibility, add /Applications/Yappie.app again, then switch it on."
        }
        return "Add /Applications/Yappie.app in Privacy & Security ▸ Accessibility, then switch it on."
    }
}

// MARK: - Transcriptions

/// Past transcriptions, searchable, each copyable.
private struct TranscriptionList: View {
    @State private var store = RunStore.shared
    @State private var query = ""
    @State private var isConfirmingClear = false

    private var runs: [DictationRun] {
        let all = store.runs.reversed().map { $0 }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.text.localizedStandardContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $query, placeholder: "Search transcriptions")

            if runs.isEmpty {
                EmptyPanel(
                    label: store.runs.isEmpty ? "No recordings" : "No matches",
                    detail: store.runs.isEmpty
                        ? "Hold \(Settings.shared.pushToTalkKey.displayName) and talk, or press Record."
                        : "Try a different search."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(runs) { run in
                            TranscriptionRow(run: run) {
                                withAnimation(DS.Motion.panel) { RunLog.delete(run) }
                            }
                        }
                    }
                    .padding(DS.Space.base)
                }
                footer
            }
        }
    }

    private var footer: some View {
        HStack {
            Silkscreen(
                text: "\(store.runs.count) recording\(store.runs.count == 1 ? "" : "s")",
                color: DS.Color.inkOnDeckMuted
            )
            Spacer()
            Button { isConfirmingClear = true } label: {
                Silkscreen(text: "Delete all", color: DS.Color.inkOnDeckMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.snug)
        .background(DS.Color.deck)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.Color.deckHairline).frame(height: DS.Border.seam)
        }
        // Confirmed, unlike a single row: one row is trivially re-recorded, the whole
        // history is not, and there's no undo.
        .confirmationDialog(
            "Delete all \(store.runs.count) recordings?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { RunLog.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }
}

private struct TranscriptionRow: View {
    let run: DictationRun
    let onDelete: () -> Void

    @State private var didCopy = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            HStack(spacing: DS.Space.snug) {
                Silkscreen(text: run.engine, color: DS.Color.inkOnDeckStrong)
                Readout(text: String(format: "%.2fs", run.processSeconds))
                    .foregroundStyle(DS.Color.inkOnDeckMuted)
                Spacer()
                Text(run.date, style: .time)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkOnDeckMuted)
                copyButton
                teachButton
                deleteButton
                    .opacity(isHovering ? 1 : 0)
            }

            Text(run.text)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.inkOnDeck)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let corrections = run.corrections, !corrections.isEmpty {
                CorrectionBadges(corrections: corrections)
            }
        }
        .padding(DS.Space.base)
        .background(isHovering ? DS.Color.deckHover : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.Color.deckHairline)
                .frame(height: DS.Border.hairline)
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Teach dictionary…") {
                DictionaryStore.shared.beginTeach(transcript: run.text)
            }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(run.text, forType: .string)
            }
        }
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(run.text, forType: .string)
            didCopy = true
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                didCopy = false
            }
        } label: {
            Silkscreen(
                text: didCopy ? "Copied" : "Copy",
                color: didCopy ? DS.Color.inkOnDeck : DS.Color.inkOnDeckMuted
            )
            .padding(.horizontal, DS.Space.snug)
            .padding(.vertical, DS.Space.tight)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip)
                    .strokeBorder(DS.Color.deckHairline, lineWidth: DS.Border.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    /// Opens the dictionary editor with this transcript as tappable words, so a misspelling
    /// can be taught without retyping it.
    private var teachButton: some View {
        Button {
            DictionaryStore.shared.beginTeach(transcript: run.text)
        } label: {
            Silkscreen(
                text: "Teach",
                color: DS.Color.inkOnDeckMuted
            )
            .padding(.horizontal, DS.Space.snug)
            .padding(.vertical, DS.Space.tight)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip)
                    .strokeBorder(DS.Color.deckHairline, lineWidth: DS.Border.hairline)
            )
        }
        .buttonStyle(.plain)
        .help("Add words from this transcript to the dictionary")
        .disabled(run.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// Appears on hover only, and deletes without a confirmation — a single transcript is
    /// cheap to redo, and a dialog on every row would make tidying up tedious. The
    /// irreversible one is "Delete all", which does confirm.
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(DS.Font.iconTiny)
                .foregroundStyle(DS.Color.inkOnDeckMuted)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.tight)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(DS.Color.deckHairline, lineWidth: DS.Border.hairline)
                )
        }
        .buttonStyle(.plain)
        .help("Delete this transcription")
    }
}

/// Shows that the dictionary fired, and on what. Without this the dictionary is invisible
/// and you can't tell a rule that works from one that never matches.
private struct CorrectionBadges: View {
    let corrections: [AppliedCorrection]

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            Silkscreen(text: "Corrected", color: DS.Color.meterAmber)
            ForEach(corrections, id: \.self) { correction in
                HStack(spacing: DS.Space.tight) {
                    Text(correction.from)
                        .strikethrough()
                        .foregroundStyle(DS.Color.inkOnDeck.opacity(0.5))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(DS.Color.inkOnDeck.opacity(0.4))
                    Text(correction.to)
                        .foregroundStyle(DS.Color.inkOnDeck)
                    if correction.count > 1 {
                        Text("×\(correction.count)")
                            .foregroundStyle(DS.Color.inkOnDeck.opacity(0.5))
                    }
                }
                .font(DS.Font.caption)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.hair)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(DS.Color.meterAmber.opacity(0.35), lineWidth: DS.Border.hairline)
                )
            }
            Spacer()
        }
    }
}

// MARK: - Shared

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            Image(systemName: "magnifyingglass")
                .font(DS.Font.iconSmall)
                .foregroundStyle(DS.Color.inkOnDeckMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.inkOnDeck)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Color.inkOnDeckFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.snug)
        .background(DS.Color.deck)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Color.deckHairline).frame(height: DS.Border.seam)
        }
    }
}

struct EmptyPanel: View {
    let label: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            Silkscreen(text: label, large: true, color: DS.Color.inkOnDeckMuted)
            Text(detail)
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.inkOnDeckFaint)
        }
        .padding(.horizontal, DS.Space.roomy)
        .padding(.top, DS.Space.panel)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
