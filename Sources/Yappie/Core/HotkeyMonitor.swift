import AppKit
import Carbon.HIToolbox
import Foundation

/// Device-dependent bits from IOKit `IOLLEvent.h`. Public `CGEventFlags` has no
/// left/right split — `maskAlternate` is on whenever *either* Option key is down.
///
/// Confirmed against the macOS SDK:
/// `NX_DEVICELCMDKEYMASK 0x08`, `NX_DEVICERCMDKEYMASK 0x10`,
/// `NX_DEVICELALTKEYMASK 0x20`, `NX_DEVICERALTKEYMASK 0x40`.
private enum NXDevice {
    static let leftCommand    = CGEventFlags(rawValue: 0x0000_0008)
    static let rightCommand   = CGEventFlags(rawValue: 0x0000_0010)
    static let leftAlternate  = CGEventFlags(rawValue: 0x0000_0020)
    static let rightAlternate = CGEventFlags(rawValue: 0x0000_0040)
}

/// Which modifier key holds the mic open.
enum PushToTalkKey: String, CaseIterable, Sendable {
    case leftOption
    case rightOption
    case fn
    case rightCommand

    var keyCode: Int64 {
        switch self {
        case .leftOption: Int64(kVK_Option)         // 58 — Carbon has no kVK_LeftOption
        case .rightOption: Int64(kVK_RightOption)   // 61
        case .fn: Int64(kVK_Function)               // 63
        case .rightCommand: Int64(kVK_RightCommand) // 54
        }
    }

    /// Device-*dependent* bit for this specific physical key.
    ///
    /// `CGEventFlags.maskAlternate` is the union mask — it's set whenever *either* Option
    /// key is down. Using it means: hold Left ⌥, tap Right ⌥, and the release is invisible
    /// (the union bit is still set by the left key), so `onRelease` never fires. The mic
    /// stays open, the HUD stays up, and the next press is swallowed too.
    var flag: CGEventFlags {
        switch self {
        case .leftOption: NXDevice.leftAlternate
        case .rightOption: NXDevice.rightAlternate
        case .rightCommand: NXDevice.rightCommand
        case .fn: .maskSecondaryFn
        }
    }

    /// Union mask that does not distinguish left from right. Fallback only, when the
    /// device bit is missing from this event and the opposite side isn't what's holding
    /// the union on.
    var unionFlag: CGEventFlags {
        switch self {
        case .leftOption, .rightOption: .maskAlternate
        case .rightCommand: .maskCommand
        case .fn: .maskSecondaryFn
        }
    }

    var oppositeFlag: CGEventFlags? {
        switch self {
        case .leftOption: NXDevice.rightAlternate
        case .rightOption: NXDevice.leftAlternate
        case .rightCommand: NXDevice.leftCommand
        case .fn: nil
        }
    }

    var displayName: String {
        switch self {
        case .leftOption: "Left ⌥"
        case .rightOption: "Right ⌥"
        case .fn: "fn"
        case .rightCommand: "Right ⌘"
        }
    }

    /// Swallowing `fn` would break fn+arrow, fn+delete and the emoji picker, so we let it
    /// through. Dedicated Option and right-⌘ keys are consumed so they don't leak into
    /// the focused app while you dictate.
    var shouldConsumeEvent: Bool { self != .fn }

    /// Whether this physical key is down in `flags`, given that `keyCode` is the key
    /// that just changed.
    func isDown(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard keyCode == self.keyCode else { return false }
        if flags.contains(flag) { return true }
        if let oppositeFlag, flags.contains(oppositeFlag) { return false }
        return flags.contains(unionFlag)
    }
}

/// Result of listening for a modifier to bind as the push-to-talk key.
enum PushToTalkBindOutcome: Equatable, Sendable {
    case picked(PushToTalkKey)
    /// Left ⌘ is every system shortcut. Binding it as a hold-to-talk key, and especially
    /// swallowing it, would break Copy, Paste, Quit, and the rest.
    case rejectedLeftCommand
}

extension PushToTalkKey {
    /// Interprets a flags-changed event as a bind press. Release events return `nil`.
    static func bindOutcome(keyCode: Int64, flags: CGEventFlags) -> PushToTalkBindOutcome? {
        if keyCode == Int64(kVK_Command) {
            return flags.contains(.maskCommand) ? .rejectedLeftCommand : nil
        }
        guard let key = allCases.first(where: { $0.keyCode == keyCode }) else { return nil }
        return key.isDown(keyCode: keyCode, flags: flags) ? .picked(key) : nil
    }
}

/// Listens for the next supported modifier so the user can bind a push-to-talk key
/// from the main window. Uses `NSEvent` monitors rather than a tap: local monitors
/// work while the window is focused even before Accessibility is granted.
@MainActor
final class PushToTalkBinder {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var generation = 0
    private var onOutcome: ((PushToTalkBindOutcome) -> Void)?

    func start(onOutcome: @escaping (PushToTalkBindOutcome) -> Void) {
        stop()
        self.onOutcome = onOutcome
        let gen = generation

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let keyCode = Int64(event.keyCode)
            let flags = event.cgEvent?.flags ?? CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            Task { @MainActor in
                self?.consider(keyCode: keyCode, flags: flags, generation: gen)
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let keyCode = Int64(event.keyCode)
            let flags = event.cgEvent?.flags ?? CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            Task { @MainActor in
                self?.consider(keyCode: keyCode, flags: flags, generation: gen)
            }
        }
    }

    func stop() {
        generation += 1
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        onOutcome = nil
    }

    private func consider(keyCode: Int64, flags: CGEventFlags, generation: Int) {
        guard generation == self.generation else { return }
        guard let outcome = PushToTalkKey.bindOutcome(keyCode: keyCode, flags: flags) else { return }
        switch outcome {
        case .picked:
            let callback = onOutcome
            stop()
            callback?(outcome)
        case .rejectedLeftCommand:
            onOutcome?(outcome)
        }
    }
}

/// Watches for a held modifier key using a `CGEventTap`.
///
/// A tap is required rather than `NSEvent.addGlobalMonitor` because `fn` and left/right
/// modifier discrimination don't surface through the higher-level APIs. This needs
/// Accessibility permission; without it `CGEvent.tapCreate` returns nil.
@MainActor
final class HotkeyMonitor {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isPressed = false
    private var didWarnTapFailure = false

    var key: PushToTalkKey = .leftOption
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    /// - Returns: `false` if the tap couldn't be created — almost always missing Accessibility permission.
    @discardableResult
    func start() -> Bool {
        stop()

        let mask = (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

                // CGEvent isn't Sendable, so pull out the plain values before crossing into
                // actor-isolated code. The tap was added to the main run loop, so this
                // callback genuinely does run on the main thread.
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                let consume = MainActor.assumeIsolated {
                    monitor.handle(type: type, keyCode: keyCode, flags: flags)
                }
                return consume ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            if !didWarnTapFailure {
                Log.hotkey.error("tapCreate failed — Accessibility permission missing?")
                didWarnTapFailure = true
            }
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        didWarnTapFailure = false

        Log.hotkey.info("listening for \(self.key.displayName)")
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isPressed = false
    }

    // MARK: - Tap callback

    /// - Returns: `true` if the event should be swallowed rather than passed along.
    private func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) -> Bool {
        // The system disables a tap that runs too slowly or is interrupted; re-arm it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }

        guard type == .flagsChanged, keyCode == key.keyCode else { return false }

        let nowPressed = key.isDown(keyCode: keyCode, flags: flags)
        guard nowPressed != isPressed else { return false }
        isPressed = nowPressed

        if nowPressed { onPress?() } else { onRelease?() }

        return key.shouldConsumeEvent
    }
}
