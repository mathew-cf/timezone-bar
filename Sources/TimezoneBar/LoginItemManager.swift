import Foundation
import ServiceManagement

/// Manages the "launch at login" setting using SMAppService (macOS 13+).
///
/// SMAppService requires the app to be running from a signed .app bundle.
/// When running via `swift run` (bare executable), registration will fail
/// gracefully and `isAvailable` will be false.
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    private let service = SMAppService.mainApp

    /// Whether SMAppService is usable (i.e. running from a .app bundle).
    var isAvailable: Bool {
        // SMAppService.mainApp works when there's a valid bundle identifier.
        return Bundle.main.bundleIdentifier != nil
    }

    /// Current login item status, derived from SMAppService.
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            setLoginItem(enabled: launchAtLogin)
        }
    }

    private init() {
        self.launchAtLogin = Self.currentStatus()
    }

    /// Testable init for overriding initial state.
    init(initialValue: Bool) {
        self.launchAtLogin = initialValue
    }

    private static func currentStatus() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // If registration fails (e.g. not in a .app bundle), revert
            DispatchQueue.main.async { [weak self] in
                self?.launchAtLogin = Self.currentStatus()
            }
        }
    }
}
