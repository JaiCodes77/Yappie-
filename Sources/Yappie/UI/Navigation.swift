import Observation
import SwiftUI

/// The three things the page can show.
enum WorkspaceSection: String, CaseIterable, Identifiable, Hashable {
    case transcriptions
    case dictionary
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transcriptions: "Transcriptions"
        case .dictionary: "Dictionary"
        case .activity: "Activity"
        }
    }

    var symbol: String {
        switch self {
        case .transcriptions: "text.quote"
        case .dictionary: "character.book.closed"
        case .activity: "chart.bar.xaxis"
        }
    }

    /// ⌘1, ⌘2, ⌘3 — the macOS convention for switching what one window is showing.
    var shortcut: KeyEquivalent {
        switch self {
        case .transcriptions: "1"
        case .dictionary: "2"
        case .activity: "3"
        }
    }
}

/// Which section the window is showing.
///
/// App-level rather than `@State` inside the window, so the View menu can drive it. A
/// keyboard shortcut buried in a hidden button works but is undiscoverable; a real menu
/// item shows the user the shortcut exists.
@MainActor
@Observable
final class Navigation {
    static let shared = Navigation()

    /// Remembered across launches. `make install` relaunches the app several times an hour
    /// while you're working on it, and landing back on Transcriptions every time is a small
    /// tax on a window you were using for something else.
    var section: WorkspaceSection {
        didSet { UserDefaults.standard.set(section.rawValue, forKey: Self.sectionKey) }
    }

    /// Set when a section wants the keyboard focus in its search field (⌘F).
    var focusSearchToken = 0

    private static let sectionKey = "workspaceSection"

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.sectionKey) ?? ""
        section = WorkspaceSection(rawValue: raw) ?? .transcriptions
    }

    func show(_ section: WorkspaceSection) {
        withAnimation(DS.Motion.panel) { self.section = section }
    }

    func focusSearch() {
        focusSearchToken += 1
    }
}
