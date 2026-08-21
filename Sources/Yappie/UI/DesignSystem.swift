import SwiftUI

/// The design system for Yappie.
///
/// Direction: a copy desk for speech. Words you spoke sit on an amber phosphor page —
/// one memorable surface. Everything around it is a quiet cool limestone editor (night-ink
/// in dark appearance). Copper marks selection. Red is recording, and nothing else.
///
/// Deliberately not a cassette deck, not AI-SaaS purple, not system gray.
///
/// Every value a view needs lives here; components never declare their own colors, sizes,
/// radii or durations.
enum DS {

    // MARK: - Color

    enum Color {
        /// Window chrome. Cool limestone in light, night-ink in dark — not cream, not black.
        static let chassis = face(light: 0xD5D9E0, dark: 0x0B0F14)

        /// Raised cards sitting on the chassis.
        static let panel = face(light: 0xEEEFF3, dark: 0x151A21)

        static let panelHighlight = face(light: 0xFFFFFF, dark: 0x222833)
        static let panelShade = face(light: 0xC5CAD3, dark: 0x0A0D12)

        /// Recessed list wells that are *not* the phosphor page (settings, comparison).
        static let well = face(light: 0xE2E5EB, dark: 0x10151C)

        /// The phosphor page. Always dark amber, both appearances — transcripts live here.
        static let deck = swatch(0x16110A)

        /// Control faces.
        static let cap = face(light: 0xF7F8FA, dark: 0x1C232C)

        static let seam = face(light: 0xC2C7D0, dark: 0x2A313C)

        static let ink = face(light: 0x16181E, dark: 0xE8E4DA)
        static let inkSecondary = face(light: 0x5C6370, dark: 0x9AA19A)
        static let silkscreen = face(light: 0x3A404C, dark: 0xB4B8B0)
        /// Phosphor type on the amber page.
        static let inkOnDeck = swatch(0xF0D39A)

        /// Selection and engaged chrome that is not recording.
        static let copper = swatch(0xC4783A)
        static let copperSoft = swatch(0xC4783A).opacity(0.16)

        static let record = swatch(0xC8342A)
        static let recordIdle = face(light: 0xC4A8A4, dark: 0x4A2724)

        static let selection = face(light: 0xE8D5C4, dark: 0x2A2118)
        static let selectionEdge = swatch(0xC4783A)
        static let focusRing = swatch(0xC4783A)
        static let hover = face(light: 0xE4E7ED, dark: 0x1C232C)

        // Instrumentation only — the ink-line and correction marks.
        static let meterFace = swatch(0x16110A)
        static let meterLamp = swatch(0xC4783A)
        static let meterNeedle = swatch(0xF0D39A)
        static let meterGreen = swatch(0x6F9E45)
        static let meterAmber = swatch(0xE0A04A)
        static let meterRed = swatch(0xC8342A)

        private static func swatch(_ hex: UInt32) -> SwiftUI.Color { SwiftUI.Color(hex: hex) }

        private static func face(light: UInt32, dark: UInt32) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light)
            })
        }
    }

    // MARK: - Material

    enum Material {
        static let grainLight: Double = 0
        static let grainDark: Double = 0
        static let grainPitch: CGFloat = 4
        static let grainAngle: Angle = .degrees(0)

        static let screwSize: CGFloat = 0
        static let screwInset: CGFloat = 0

        static let ventSlotWidth: CGFloat = 0
        static let ventSlotHeight: CGFloat = 0
        static let ventSlotGap: CGFloat = 0
        static let ventRadius: CGFloat = 0

        static let lampSize: CGFloat = 8
        static let lampSpecular: Double = 0.5
        static let lampUnlitOpacity: Double = 0.28

        static let segmentThickness: CGFloat = 3
        static let segmentGap: CGFloat = 1
        static let segmentGhostOpacity: Double = 0.12

        static let keyHeight: CGFloat = 32
        static let keyMinWidth: CGFloat = 48
        static let keyTravel: CGFloat = 0.5

        static let needleSweep: Angle = .degrees(0)
        static let needleWidth: CGFloat = 1.75
        static let meterZeroPoint: Double = 0.72
        static let inkLineWidth: CGFloat = 1.75
        static let waveformBars: Int = 48
    }

    // MARK: - Type

    /// Condensed geometric labels (Avenir Next Condensed) against a literary serif for
    /// the words you spoke (New York). Counters stay monospaced.
    enum Font {
        private static let display = "Avenir Next Condensed"

        static let silkscreen = named(size: 11, weight: .semibold)
        static let silkscreenLarge = named(size: 13, weight: .semibold)

        static let caption = serif(size: 11, weight: .regular)
        static let label = named(size: 12, weight: .regular)
        static let body = serif(size: 15, weight: .regular)
        static let bodyEmphasis = serif(size: 15, weight: .medium)
        static let title = named(size: 22, weight: .semibold)

        static let counter = SwiftUI.Font.system(size: 13, design: .monospaced).monospacedDigit()
        static let counterLarge = SwiftUI.Font.system(size: 28, weight: .medium, design: .monospaced)
            .monospacedDigit()

        static let silkscreenTracking: CGFloat = 0.6

        private static func named(size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
            .custom(display, size: size).weight(weight)
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
        static let chipWell: CGFloat = 80
        static let editorSheet: CGFloat = 460
        static let hudWidth: CGFloat = 360
        static let hudHeight: CGFloat = 80
        static let waveformWidth: CGFloat = 92
        static let waveformHeight: CGFloat = 28
        static let meterWidth: CGFloat = 180
        static let meterHeight: CGFloat = 48
        static let settingsWidth: CGFloat = 580
        static let settingsHeight: CGFloat = 460
        static let mainMinWidth: CGFloat = 720
        static let mainMinHeight: CGFloat = 520
        static let comparisonMinWidth: CGFloat = 560
        static let comparisonMinHeight: CGFloat = 420
        static let hudLift: CGFloat = 96
    }

    // MARK: - Radius

    enum Radius {
        static let none: CGFloat = 0
        static let chip: CGFloat = 6
        static let control: CGFloat = 8
        static let panel: CGFloat = 12
        static let window: CGFloat = 16
    }

    // MARK: - Border

    enum Border {
        static let hairline: CGFloat = 1
        static let seam: CGFloat = 1
        static let bevel: CGFloat = 1
    }

    // MARK: - Elevation

    enum Shadow {
        static let raised = Spec(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        static let pressed = Spec(color: .black.opacity(0.04), radius: 2, x: 0, y: 0)
        static let panel = Spec(color: .black.opacity(0.10), radius: 16, x: 0, y: 4)
        static let window = Spec(color: .black.opacity(0.22), radius: 28, x: 0, y: 10)
        static let phosphor = Spec(color: DS.Color.copper.opacity(0.18), radius: 12, x: 0, y: 0)

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
        static let panel = Animation.easeInOut(duration: 0.2)
        static let lamp = Animation.easeOut(duration: 0.08)
        static let needleAttack: TimeInterval = 0.22
        static let needleRelease: TimeInterval = 0.36
        static let needleOvershoot: Double = 0.04
        static let hud: TimeInterval = 0.18
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
