import YappieDictionary
import AppKit
import SwiftUI

/// The dictionary: add, edit, delete, search.
///
/// Both entry kinds live in one list rather than separate tabs — they're two shapes of the
/// same idea and you want to see everything you've taught it at once. The kind is carried by
/// a silkscreen tag on each row.
struct DictionaryPanel: View {
    @State private var store = DictionaryStore.shared
    @State private var query = ""

    private var entries: [DictionaryEntry] { store.filtered(by: query) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SearchField(text: $query, placeholder: "Search dictionary")
                addButton
                    .padding(.trailing, DS.Space.base)
                    .background(DS.Color.deck)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(DS.Color.deckHairline).frame(height: DS.Border.seam)
            }

            if entries.isEmpty {
                EmptyPanel(
                    label: store.entries.isEmpty ? "Dictionary empty" : "No matches",
                    detail: store.entries.isEmpty
                        ? "Add a name the engine should know, or a correction for a misspelling. You can also tap Teach on a transcription and pick the words."
                        : "Try a different search."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Space.tight) {
                        ForEach(entries) { entry in
                            DictionaryRow(
                                entry: entry,
                                onEdit: { store.beginEdit(entry) },
                                onToggle: {
                                    var updated = entry
                                    updated.isEnabled.toggle()
                                    store.update(updated)
                                },
                                onDelete: { store.delete(entry) }
                            )
                        }
                    }
                    .padding(DS.Space.base)
                }
            }

            footer
        }
    }

    private var addButton: some View {
        Button { store.beginAdd() } label: {
            HStack(spacing: DS.Space.tight) {
                Image(systemName: "plus")
                    .font(DS.Font.iconTiny)
                Silkscreen(text: "Add", color: DS.Color.inkOnDeck)
            }
            .foregroundStyle(DS.Color.inkOnDeck)
            .padding(.horizontal, DS.Space.base)
            .padding(.vertical, DS.Space.snug)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip)
                    .strokeBorder(DS.Color.deckHairline, lineWidth: DS.Border.hairline)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
    }

    /// The file path is shown because the spec asks for the dictionary to be editable outside
    /// the UI — which is only true if you can find it.
    private var footer: some View {
        HStack(spacing: DS.Space.snug) {
            Silkscreen(text: "\(store.entries.count) entries", color: DS.Color.inkOnDeckMuted)
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([DictionaryStore.fileURL])
            } label: {
                Silkscreen(text: "Reveal dictionary.txt", color: DS.Color.inkOnDeckMuted)
            }
            .buttonStyle(.plain)
            .help(DictionaryStore.fileURL.path)
        }
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.snug)
        .background(DS.Color.deck)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.Color.deckHairline).frame(height: DS.Border.seam)
        }
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
            Lamp(color: DS.Color.meterGreen, isLit: entry.isEnabled, size: 6)

            Silkscreen(
                text: entry.kind == .correction ? "Fix" : "Term",
                color: DS.Color.inkOnDeckMuted
            )
            .frame(width: 34, alignment: .leading)

            if entry.kind == .correction {
                Text(entry.hear)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.inkOnDeckMuted)
                Image(systemName: "arrow.right")
                    .font(DS.Font.iconTiny)
                    .foregroundStyle(DS.Color.inkOnDeckFaint)
            }

            Text(entry.write)
                .font(DS.Font.bodyEmphasis)
                .foregroundStyle(DS.Color.inkOnDeck)

            Spacer()

            if isHovering {
                rowButton("Edit", action: onEdit)
                rowButton(entry.isEnabled ? "Off" : "On", action: onToggle)
                rowButton("Delete", action: onDelete)
            }
        }
        .opacity(entry.isEnabled ? 1 : 0.45)
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.snug)
        .background(isHovering ? DS.Color.deckHover : DS.Color.deck, in: .rect(cornerRadius: DS.Radius.chip))
        .onHover { isHovering = $0 }
    }

    private func rowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Silkscreen(text: title, color: DS.Color.inkOnDeckMuted)
        }
        .buttonStyle(.plain)
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
        case .teach: "Teach from transcript"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.roomy) {
            Silkscreen(text: title, large: true)

            if !tokens.isEmpty {
                wordChips
            }

            kindPicker

            VStack(alignment: .leading, spacing: DS.Space.base) {
                if kind == .correction {
                    field("When you hear", text: $hear, prompt: "cloud code")
                }
                field(
                    kind == .correction ? "Write" : "Word or phrase",
                    text: $write,
                    prompt: kind == .correction ? "Claude Code" : "Anthropic"
                )
            }

            ForEach(warnings) { warning in
                HStack(alignment: .top, spacing: DS.Space.snug) {
                    Lamp(color: DS.Color.meterAmber, isLit: true, size: 6)
                        .padding(.top, 3)
                    Text(warning.message)
                        .font(DS.Font.label)
                        .foregroundStyle(DS.Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Space.snug)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(DS.Color.meterAmber.opacity(0.4), lineWidth: DS.Border.hairline)
                )
            }

            HStack(spacing: DS.Space.snug) {
                Spacer()
                TransportKey(title: "Cancel") { dismiss() }
                TransportKey(title: "Save", isEngaged: isValid, engagedColor: DS.Color.copper) {
                    guard isValid else { return }
                    onSave(draft)
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
        .padding(DS.Space.panel)
        .frame(width: DS.Size.editorSheet)
        .background(BrushedPanel(radius: DS.Radius.window))
        .onChange(of: selectedTokenIDs) { _, _ in applySelectedPhrase() }
        .onChange(of: kind) { _, _ in applySelectedPhrase() }
    }

    /// Tappable words from the transcript. Selected chips fill "when you hear" (or the
    /// term itself), so you don't have to retype a misspelling to correct it.
    private var wordChips: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            Silkscreen(text: "Tap the words it got wrong")
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
            }
            .frame(maxHeight: DS.Size.chipWell)
            .padding(DS.Space.snug)
            .background(DS.Color.deck, in: .rect(cornerRadius: DS.Radius.chip))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip)
                    .strokeBorder(DS.Color.seam, lineWidth: DS.Border.hairline)
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
            ForEach([DictionaryEntry.Kind.term, .correction], id: \.self) { candidate in
                TransportKey(
                    title: candidate == .term ? "Term" : "Correction",
                    isEngaged: kind == candidate,
                    engagedColor: DS.Color.copper
                ) {
                    withAnimation(DS.Motion.panel) { kind = candidate }
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.tight) {
            Silkscreen(text: label)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.inkOnDeck)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.snug)
                .background(DS.Color.deck, in: .rect(cornerRadius: DS.Radius.chip))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(DS.Color.seam, lineWidth: DS.Border.hairline)
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

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkOnDeck)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.tight)
                .background(
                    isSelected ? DS.Color.inkOnDeck.opacity(0.18) : Color.clear,
                    in: .rect(cornerRadius: DS.Radius.chip)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(
                            DS.Color.inkOnDeck.opacity(isSelected ? 0.55 : 0.28),
                            lineWidth: DS.Border.hairline
                        )
                )
        }
        .buttonStyle(.plain)
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
