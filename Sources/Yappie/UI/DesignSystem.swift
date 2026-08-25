import SwiftUI

/// The design system for Yappie.
///
/// Direction: a copy desk for speech. Words you spoke sit on a **page** — warm paper in
/// light appearance, aubergine phosphor in dark. Everything around the page is quieter
/// violet-grey chrome. Copper marks selection. Red is recording, and nothing else.
///
/// Deliberately not a cassette deck, not neon AI-SaaS purple, not system gray.
///
/// Every value a view needs lives here; components never declare their own colors, sizes,
/// radii or durations.
enum DS {

    // MARK: - Color

    /// Three surfaces, in order of elevation: `chassis` (the window), `bar` (raised chrome
    /// and cards), `page` (the recessed reading surface). Each is a distinct value in *both*
    /// appearances — a surface you cannot see is not a surface.
    enum Color {

        // MARK: Chrome

        /// The window background. Everything else sits on it.
        static let chassis = face(light: 0xE8E4EC, dark: 0x1A1520)

        /// Raised chrome: the control bar, cards, sheets.
        static let bar = face(light: 0xF5F2F8, dark: 0x241E2E)

        /// Control faces — buttons, menus, fields in the chrome.
        static let cap = face(light: 0xFFFFFF, dark: 0x2E2739)

        /// Hairline between chrome surfaces.
        static let seam = face(light: 0xD5CFDC, dark: 0x352C42)

        /// Hover tint for chrome controls.
        static let capHover = face(light: 0xEDE8F2, dark: 0x393046)

        static let ink = face(light: 0x1B1720, dark: 0xEFE9F3)
        static let inkSecondary = face(light: 0x62596B, dark: 0xA79DAF)
        /// Small editorial labels on chrome.
        static let inkLabel = face(light: 0x4A4253, dark: 0xB9AFC3)

        // MARK: The page

        /// The reading surface. Warm paper in light, aubergine phosphor in dark.
        static let page = face(light: 0xFBF8F3, dark: 0x0E0A14)

        /// A row on the page under the pointer.
        static let pageHover = face(light: 0xF2ECE1, dark: 0x191223)

        /// A row on the page that is selected or otherwise held open.
        static let pageRaised = face(light: 0xEFE8DB, dark: 0x1E1629)

        /// Rules and dividers drawn on the page.
        static let pageRule = face(light: 0xE4DBCB, dark: 0x2B2137)

        /// The page's own outer edge.
        static let pageEdge = face(light: 0xDCD2C0, dark: 0x2F2442)

        static let inkOnPage = face(light: 0x1F1A26, dark: 0xEEE4F8)
        static let inkOnPageStrong = face(light: 0x3A3244, dark: 0xD1C4E2)
        /// Secondary type on the page. Holds 4.5:1 in both appearances.
        static let inkOnPageMuted = face(light: 0x6B6272, dark: 0xA398B4)
        /// Decoration only — legend captions, weekday initials. Never essential copy.
        static let inkOnPageFaint = face(light: 0x8E8697, dark: 0x796E89)

        // MARK: Accents

        /// Selection, and engaged chrome that is not recording.
        static let copper = face(light: 0xA85F26, dark: 0xD08A4A)
        static let copperSoft = face(light: 0xA85F26, dark: 0xD08A4A).opacity(0.14)

        /// Electrical signal color: the level meter and the activity ramp.
        static let violet = face(light: 0x6D46A8, dark: 0xA87DD8)

        /// Recording. Nothing else in the app is red.
        static let record = face(light: 0xC0392B, dark: 0xE05A4E)

        /// Armed and ready.
        static let positive = face(light: 0x40702A, dark: 0x86BB57)
        /// A caution that is not a failure — a dictionary rule that fired, a warning.
        static let caution = face(light: 0x8A5D0F, dark: 0xE0A04A)

        // MARK: The activity ramp

        /// Words per day on the page. Never red — red is recording.
        static let rampEmpty = face(light: 0xE9E2D6, dark: 0x1C1528)
        static let rampFaint = violet.opacity(0.26)
        static let rampLow = violet.opacity(0.46)
        static let rampMid = violet.opacity(0.70)
        static let rampFull = violet
        /// A day that has not happened yet.
        static let rampFuture = face(light: 0xF4F0E8, dark: 0x130E1B)

        // MARK: Focus

        static let focusRing = face(light: 0xA85F26, dark: 0xD08A4A)

        /// Alphas views apply to an accent to derive a tint or an edge from it.
        ///
        /// Named here rather than inlined at the call site so the whole system can be
        /// re-tuned in one place — the same reason the colours themselves live here.
        enum Alpha {
            /// Wash behind a warning or an accented block.
            static let tint: Double = 0.10
            /// Faint wash — a badge that shouldn't compete with the text on it.
            static let wash: Double = 0.08
            /// Edge of an accented block.
            static let edge: Double = 0.35
            /// Edge of an engaged control, or the recording ring.
            static let engagedEdge: Double = 0.50
            /// Edge of a selected chip.
            static let selectedEdge: Double = 0.60
            /// A lamp that is off.
            static let lampOff: Double = 0.22
            /// The halo around a lit lamp.
            static let lampHalo: Double = 0.35
            /// The level meter's resting rule.
            static let meterRest: Double = 0.45
            /// Row actions before the pointer reaches them.
            static let quiet: Double = 0.55
            /// A dictionary entry that is switched off.
            static let disabled: Double = 0.50
        }

        private static func face(light: UInt32, dark: UInt32) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light)
            })
        }
    }

    // MARK: - Type

    /// System sans for chrome, New York serif for the words you spoke. The serif is the
    /// point: a transcript should read like copy, not like a log line. Counters are
    /// monospaced so a running clock doesn't jitter.
    enum Font {
        /// Small editorial label — a kicker above a value or a section.
        static let eyebrow = sans(size: 11, weight: .semibold)
        static let eyebrowLarge = sans(size: 13, weight: .semibold)
        static let eyebrowTracking: CGFloat = 0.3

        static let caption = sans(size: 11, weight: .regular)
        static let label = sans(size: 12, weight: .regular)
        static let labelEmphasis = sans(size: 12, weight: .medium)
        static let title = sans(size: 15, weight: .semibold)

        /// Transcripts.
        static let body = serif(size: 15, weight: .regular)
        static let bodyEmphasis = serif(size: 15, weight: .medium)
        static let hud = serif(size: 13, weight: .regular)

        static let iconSmall = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let iconTiny = SwiftUI.Font.system(size: 9, weight: .semibold)
        /// The arrow inside a correction badge.
        static let iconMicro = SwiftUI.Font.system(size: 7, weight: .bold)
        /// The glyph on an empty page.
        static let glyph = SwiftUI.Font.system(size: 26, weight: .light)

        static let counter = SwiftUI.Font.system(size: 12, design: .monospaced).monospacedDigit()
        static let counterLarge = SwiftUI.Font.system(size: 26, weight: .medium, design: .monospaced)
            .monospacedDigit()
        static let weekday = sans(size: 9, weight: .semibold)

        private static func sans(size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
            .system(size: size, weight: weight)
        }

        private static func serif(size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .serif)
        }
    }

    // MARK: - Spacing

    enum Space {
        static let hair: CGFloat = 2
        static let tight: CGFloat = 4
        static let snug: CGFloat = 8
        static let base: CGFloat = 12
        static let roomy: CGFloat = 16
        static let wide: CGFloat = 24
        static let panel: CGFloat = 32
    }

    enum Size {
        /// Height of the window's top bar. Tall enough to hold the traffic lights, which
        /// the hidden title bar leaves floating over the content.
        static let topBar: CGFloat = 44
        /// Left gutter clearing the traffic lights.
        static let trafficLights: CGFloat = 76

        static let controlHeight: CGFloat = 28
        static let controlMinWidth: CGFloat = 44
        static let recordWidth: CGFloat = 96

        static let meterWidth: CGFloat = 72
        static let meterHeight: CGFloat = 22
        static let meterBars: Int = 32

        static let lamp: CGFloat = 7
        /// A lamp inside a list row, where 7 is too loud.
        static let lampSmall: CGFloat = 6

        static let chipWell: CGFloat = 96
        static let editorSheet: CGFloat = 460

        static let hudWidth: CGFloat = 300
        static let hudHeight: CGFloat = 44
        static let hudMeterWidth: CGFloat = 42
        static let hudMeterHeight: CGFloat = 16
        static let hudLift: CGFloat = 68

        static let settingsWidth: CGFloat = 560
        static let settingsHeight: CGFloat = 620
        static let mainMinWidth: CGFloat = 640
        static let mainMinHeight: CGFloat = 460
        static let comparisonMinWidth: CGFloat = 560
        static let comparisonMinHeight: CGFloat = 420

        // The activity page
        /// The year grid sizes its cells to the width it gets, between these bounds.
        static let rampCellMin: CGFloat = 7
        static let rampCellMax: CGFloat = 14
        static let rampGap: CGFloat = 3
        static let rampWeekdayWidth: CGFloat = 20
        static let rampMonthHeight: CGFloat = 15
        static let rampLegendCell: CGFloat = 10
        static let weekBarHeight: CGFloat = 64
        static let statColumn: CGFloat = 116
    }

    // MARK: - Radius

    enum Radius {
        static let ramp: CGFloat = 2
        static let chip: CGFloat = 5
        static let control: CGFloat = 7
        static let panel: CGFloat = 10
        static let window: CGFloat = 14
    }

    enum Border {
        static let hairline: CGFloat = 1
        static let focus: CGFloat = 2
    }

    // MARK: - Elevation

    enum Shadow {
        static let card = Spec(color: .black.opacity(0.07), radius: 6, x: 0, y: 1)
        static let hud = Spec(color: .black.opacity(0.30), radius: 18, x: 0, y: 6)

        struct Spec {
            let color: SwiftUI.Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }

    // MARK: - Motion

    enum Motion {
        static let press = Animation.easeOut(duration: 0.08)
        static let release = Animation.easeOut(duration: 0.14)
        static let panel = Animation.easeInOut(duration: 0.18)
        static let lamp = Animation.easeOut(duration: 0.08)
        /// Level-meter ballistics: fast to rise, slow to fall, so it breathes.
        static let meterAttack: TimeInterval = 0.18
        static let meterRelease: TimeInterval = 0.34
        static let hud: TimeInterval = 0.18
        /// How long the app waits for a modifier after "Set push-to-talk key".
        static let bindListen: TimeInterval = 8
        /// Accessibility has no change notification; the app polls at this interval.
        static let permissionPoll: TimeInterval = 1
    }
}

// MARK: - Hex helpers

extension SwiftUI.Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
