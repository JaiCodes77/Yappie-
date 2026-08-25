import YappieDictionary
import AppKit
import SwiftUI

/// The dictionary: add, edit, disable, delete, search.
///
/// Both entry kinds live in one list rather than separate tabs — they're two shapes of the
/// same idea and you want to see everything you've taught it at once. The kind is carried by
/// a tag on each row.
struct DictionaryPanel: View {
    @State private var store = DictionaryStore.shared
    @State private var navigation = Navigation.shared
    @State private var query = ""
    @State private var pendingDelete: DictionaryEntry?
    @FocusState private var searchFocused: Bool

    private var entries: [DictionaryEntry] { store.filtered(by: query) }

    private var terms: [DictionaryEntry] { entries.filter { $0.kind == .term } }
    private var corrections: [DictionaryEntry] { entries.filter { $0.kind == .correction } }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DS.Space.roomy, pinnedViews: .sectionHeaders) {
                        group("Corrections", "When you hear this, write that", corrections)
                        group("Terms", "Words the engine should know", terms)
                    }
                    .padding(.bottom, DS.Space.base)
                }
            }

            footer
        }
        .onChange(of: navigation.focusSearchToken) { _, _ in
            if navigation.section == .dictionary { searchFocused = true }
        }
        .confirmationDialog(
            "Delete “\(pendingDelete?.write ?? "")”?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entry = pendingDelete { store.delete(entry) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("The rule is removed from dictionary.txt.")
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ subtitle: String, _ rows: [DictionaryEntry]) -> some View {
        if !rows.isEmpty {
            Section {
                VStack(spacing: 0) {
                    ForEach(rows) { entry in
                        DictionaryRow(
                            entry: entry,
                            onEdit: { store.beginEdit(entry) },
                            onToggle: {
                                var updated = entry
                                updated.isEnabled.toggle()
                                store.update(updated)
                            },
                            onDelete: { pendingDelete = entry }
                        )
                    }
                }
            } header: {
                PageHeading(title: title, trailing: subtitle)
                    .padding(.horizontal, DS.Space.roomy)
                    .padding(.vertical, DS.Space.snug)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.page)
                    .overlay(alignment: .bottom) { Rule(onPage: true) }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            SearchField(text: $query, placeholder: "Search dictionary", focus: $searchFocused)

            PageButton(title: "Add", systemImage: "plus", isProminent: true, help: "Add a term or correction") {
                store.beginAdd()
            }
            .keyboardShortcut("n", modifiers: .command)
            .padding(.trailing, DS.Space.base)
            .background(DS.Color.page)
        }
        .overlay(alignment: .bottom) { Rule(onPage: true) }
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.entries.isEmpty {
            EmptyPage(
                symbol: "character.book.closed",
                title: "Nothing taught yet",
                detail: "Add a name the engine keeps missing, or a correction for something it "
                    + "reliably mishears. You can also press Teach on any transcription and pick "
                    + "the words."
            ) {
                PillButton(title: "Add an entry", systemImage: "plus", isEngaged: true) {
                    store.beginAdd()
                }
            }
        } else {
            EmptyPage(
                symbol: "magnifyingglass",
                title: "No matches",
                detail: "Nothing in \(store.entries.count) entries matches “\(query)”."
            ) {
                PillButton(title: "Clear search") { query = "" }
            }
        }
    }

    /// The file path is shown because the spec asks for the dictionary to be editable outside
    /// the UI — which is only true if you can find it.
    private var footer: some View {
        HStack(spacing: DS.Space.snug) {
            Eyebrow(
                text: "\(store.entries.count) entr\(store.entries.count == 1 ? "y" : "ies")",
                color: DS.Color.inkOnPageMuted
            )
            let disabled = store.entries.filter { !$0.isEnabled }.count
            if disabled > 0 {
                Eyebrow(text: "· \(disabled) off", color: DS.Color.inkOnPageFaint)
            }
            Spacer()
            PageButton(
                title: "Reveal dictionary.txt",
                systemImage: "folder",
                help: DictionaryStore.fileURL.path
            ) {
                NSWorkspace.shared.activateFileViewerSelecting([DictionaryStore.fileURL])
            }
        }
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.snug)
        .background(DS.Color.page)
        .overlay(alignment: .top) { Rule(onPage: true) }
    }
}

// MARK: - Row

private struct DictionaryRow: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DS.Space.base) {
            Lamp(
                color: entry.isEnabled ? DS.Color.positive : DS.Color.inkOnPageFaint,
                isLit: entry.isEnabled,
                size: DS.Size.lampSmall
            )

            rule

            Spacer(minLength: DS.Space.snug)

            actions
        }
        .padding(.horizontal, DS.Space.roomy)
        .padding(.vertical, DS.Space.base)
        .background(isHovering ? DS.Color.pageHover : Color.clear)
        .overlay(alignment: .bottom) { Rule(onPage: true) }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Edit…", action: onEdit)
            Button(entry.isEnabled ? "Turn off" : "Turn on", action: onToggle)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibility)
    }

    /// Corrections read as a sentence — heard on the left, written on the right. Terms are
    /// just the word.
    @ViewBuilder
    private var rule: some View {
        if entry.kind == .correction {
            HStack(spacing: DS.Space.snug) {
                Text(entry.hear)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.inkOnPageMuted)
                Image(systemName: "arrow.right")
                    .font(DS.Font.iconTiny)
                    .foregroundStyle(DS.Color.inkOnPageFaint)
                Text(entry.write)
                    .font(DS.Font.bodyEmphasis)
                    .foregroundStyle(DS.Color.inkOnPage)
            }
            .opacity(entry.isEnabled ? 1 : DS.Color.Alpha.disabled)
        } else {
            Text(entry.write)
                .font(DS.Font.bodyEmphasis)
                .foregroundStyle(DS.Color.inkOnPage)
                .opacity(entry.isEnabled ? 1 : DS.Color.Alpha.disabled)
        }
    }

    /// Always present, fading in on hover. Building these inside `if isHovering` — as the
    /// first version did — left Edit, On/Off and Delete unreachable by keyboard and
    /// invisible to VoiceOver.
    private var actions: some View {
        HStack(spacing: DS.Space.tight) {
            PageButton(title: "Edit", systemImage: "pencil", help: "Edit this entry", action: onEdit)
            PageButton(
                title: entry.isEnabled ? "On" : "Off",
                systemImage: entry.isEnabled ? "checkmark" : "slash.circle",
                help: entry.isEnabled ? "Stop applying this entry" : "Apply this entry again",
                action: onToggle
            )
            PageButton(title: "", systemImage: "trash", help: "Delete this entry", action: onDelete)
        }
        .opacity(isHovering ? 1 : DS.Color.Alpha.quiet)
        .animation(DS.Motion.release, value: isHovering)
    }

    private var accessibility: String {
        let state = entry.isEnabled ? "on" : "off"
        if entry.kind == .correction {
            return "Correction, when you hear \(entry.hear) write \(entry.write), \(state)"
        }
        return "Term, \(entry.write), \(state)"
    }
}

// MARK: - Editor

/// Add or edit one entry, with the false-positive warning shown live as you type.
///
/// When opened from a transcription (Teach), the transcript is shown as tappable chips so
/// you can pick the words the engine got wrong instead of retyping them.
struct DictionaryEditor: View {
    let request: DictionaryEditorRequest
    let onSave: (DictionaryEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: DictionaryEntry.Kind
    @State private var hear: String
    @State private var write: String
    @State private var selectedTokenIDs: Set<Int> = []
    @FocusState private var focusedField: Field?

    private enum Field { case hear, write }

    init(request: DictionaryEditorRequest, onSave: @escaping (DictionaryEntry) -> Void) {
        self.request = request
        self.onSave = onSave
        switch request.source {
        case .blank:
            _kind = State(initialValue: .term)
            _hear = State(initialValue: "")
            _write = State(initialValue: "")
        case .edit(let entry):
            _kind = State(initialValue: entry.kind)
            _hear = State(initialValue: entry.hear)
            _write = State(initialValue: entry.write)
        case .teach:
            // A transcript in front of you is almost always a misspelling to correct.
            _kind = State(initialValue: .correction)
            _hear = State(initialValue: "")
            _write = State(initialValue: "")
        }
    }

    private var existing: DictionaryEntry? {
        if case .edit(let entry) = request.source { return entry }
        return nil
    }

    private var transcript: String? {
        if case .teach(let text) = request.source { return text }
        return nil
    }

    private var tokens: [TranscriptToken] {
        guard let transcript else { return [] }
        return TranscriptToken.split(transcript)
    }

    private var selectedPhrase: String {
        tokens
            .filter { selectedTokenIDs.contains($0.id) }
            .map(\.word)
            .joined(separator: " ")
    }

    private var draft: DictionaryEntry {
        DictionaryEntry(
            id: existing?.id ?? UUID(),
            kind: kind,
            write: write.trimmingCharacters(in: .whitespacesAndNewlines),
            hear: kind == .correction ? hear.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            isEnabled: existing?.isEnabled ?? true
        )
    }

    private var warnings: [DictionaryWarning] { DictionaryWarning.check(draft) }

    private var isValid: Bool {
        !draft.write.isEmpty && (kind == .term || !draft.hear.isEmpty)
    }

    private var title: String {
        switch request.source {
        case .blank: "New entry"
        case .edit: "Edit entry"
        case .teach: "Teach from a transcript"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.roomy) {
            VStack(alignment: .leading, spacing: DS.Space.tight) {
                Text(title)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)
                Text(kindExplanation)
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !tokens.isEmpty {
                wordChips
            }

            kindPicker

            VStack(alignment: .leading, spacing: DS.Space.base) {
                if kind == .correction {
                    field("When you hear", text: $hear, prompt: "cloud code", field: .hear)
                }
                field(
                    kind == .correction ? "Write" : "Word or phrase",
                    text: $write,
                    prompt: kind == .correction ? "Claude Code" : "Anthropic",
                    field: .write
                )
            }

            ForEach(warnings) { warning in
                HStack(alignment: .top, spacing: DS.Space.snug) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DS.Font.iconTiny)
                        .foregroundStyle(DS.Color.caution)
                        .padding(.top, 2)
                    Text(warning.message)
                        .font(DS.Font.label)
                        .foregroundStyle(DS.Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Space.snug)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Color.caution.opacity(DS.Color.Alpha.tint), in: .rect(cornerRadius: DS.Radius.chip))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(DS.Color.caution.opacity(DS.Color.Alpha.edge), lineWidth: DS.Border.hairline)
                )
            }

            HStack(spacing: DS.Space.snug) {
                Spacer()
                PillButton(title: "Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                PillButton(title: "Save", isEngaged: isValid, isEnabled: isValid) { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DS.Space.panel)
        .frame(width: DS.Size.editorSheet)
        .background(DS.Color.bar)
        .onAppear { focusedField = kind == .correction && tokens.isEmpty ? .hear : .write }
        .onChange(of: selectedTokenIDs) { _, _ in applySelectedPhrase() }
        .onChange(of: kind) { _, _ in applySelectedPhrase() }
    }

    private var kindExplanation: String {
        kind == .correction
            ? "Applied after transcription, so it lands even when the engine mishears."
            : "Biases the engine toward this spelling. A nudge, not a guarantee."
    }

    private func save() {
        guard isValid else { return }
        onSave(draft)
        dismiss()
    }

    /// Tappable words from the transcript. Selected chips fill "when you hear" (or the
    /// term itself), so you don't have to retype a misspelling to correct it.
    private var wordChips: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            Eyebrow(text: "Tap the words it got wrong")
            ScrollView {
                WrappingHStack(spacing: DS.Space.tight, lineSpacing: DS.Space.tight) {
                    ForEach(tokens) { token in
                        WordChip(
                            text: token.display,
                            isSelected: selectedTokenIDs.contains(token.id)
                        ) {
                            if selectedTokenIDs.contains(token.id) {
                                selectedTokenIDs.remove(token.id)
                            } else {
                                selectedTokenIDs.insert(token.id)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Space.snug)
            }
            .frame(maxHeight: DS.Size.chipWell)
            .background(DS.Color.page, in: .rect(cornerRadius: DS.Radius.chip))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip)
                    .strokeBorder(DS.Color.pageEdge, lineWidth: DS.Border.hairline)
            )
        }
    }

    /// Chips drive the trigger side. For a term that's the word itself; for a correction
    /// it's "when you hear". The write field is left alone so a typed spelling isn't wiped.
    private func applySelectedPhrase() {
        let phrase = selectedPhrase
        guard !phrase.isEmpty else { return }
        if kind == .correction {
            hear = phrase
        } else {
            write = phrase
        }
    }

    private var kindPicker: some View {
        HStack(spacing: DS.Space.snug) {
            ForEach([DictionaryEntry.Kind.correction, .term], id: \.self) { candidate in
                PillButton(
                    title: candidate == .term ? "Term" : "Correction",
                    isEngaged: kind == candidate
                ) {
                    withAnimation(DS.Motion.panel) { kind = candidate }
                }
            }
        }
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        prompt: String,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.tight) {
            Eyebrow(text: label)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.inkOnPage)
                .focused($focusedField, equals: field)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.snug)
                .background(DS.Color.page, in: .rect(cornerRadius: DS.Radius.chip))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(
                            focusedField == field ? DS.Color.focusRing : DS.Color.pageEdge,
                            lineWidth: focusedField == field ? DS.Border.focus : DS.Border.hairline
                        )
                )
        }
    }
}

// MARK: - Teach chips

/// One whitespace-separated token from a transcript, with punctuation stripped for the
/// dictionary phrase but kept on the chip so the original reading is still visible.
struct TranscriptToken: Identifiable, Hashable {
    let id: Int
    let display: String
    let word: String

    static func split(_ text: String) -> [TranscriptToken] {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .enumerated()
            .compactMap { index, raw in
                let display = String(raw)
                let word = display.trimmingCharacters(in: .punctuationCharacters)
                guard !word.isEmpty else { return nil }
                return TranscriptToken(id: index, display: display, word: word)
            }
    }
}

private struct WordChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(DS.Font.caption)
                .foregroundStyle(isSelected ? DS.Color.copper : DS.Color.inkOnPage)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.tight)
                .background(
                    isSelected ? DS.Color.copperSoft : (isHovering ? DS.Color.pageHover : .clear),
                    in: .rect(cornerRadius: DS.Radius.chip)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(
                            isSelected ? DS.Color.copper.opacity(DS.Color.Alpha.selectedEdge) : DS.Color.pageEdge,
                            lineWidth: DS.Border.hairline
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Lays children left-to-right, wrapping onto the next line when they run out of width.
private struct WrappingHStack: Layout {
    var spacing: CGFloat = DS.Space.tight
    var lineSpacing: CGFloat = DS.Space.tight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
        }

        let height = y + rowHeight
        let width = maxWidth.isFinite ? maxWidth : usedWidth
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + lineSpacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
