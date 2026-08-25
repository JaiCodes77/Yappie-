import Foundation
import Observation

/// One place that knows whether the two grants are in place.
///
/// Accessibility has no change notification, so it has to be polled. It used to be polled
/// in three places at once — the main window's banner, the push-to-talk setup pane, and the
/// app delegate — each on its own one-second timer, each calling `AXIsProcessTrusted`, and
/// two of them re-arming the hotkey independently. This is the single poller; views observe
/// it and do nothing.
@MainActor
@Observable
final class PermissionMonitor {
    static let shared = PermissionMonitor()

    private(set) var hasAccessibility: Bool
    private(set) var hasMicrophone: Bool

    private var task: Task<Void, Never>?

    private init() {
        hasAccessibility = Permissions.hasAccessibility
        hasMicrophone = Permissions.hasMicrophone
    }

    /// Starts the poll. Called once, from the app delegate.
    ///
    /// `onTick` runs after every refresh: the delegate uses it to re-arm the hotkey the
    /// moment a grant lands, and to roll the activity ledger over at midnight.
    func start(onTick: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                onTick()
                try? await Task.sleep(for: .seconds(DS.Motion.permissionPoll))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func refresh() {
        let accessibility = Permissions.hasAccessibility
        let microphone = Permissions.hasMicrophone
        // Assigning unconditionally would wake every observer once a second.
        if accessibility != hasAccessibility { hasAccessibility = accessibility }
        if microphone != hasMicrophone { hasMicrophone = microphone }
    }
}
