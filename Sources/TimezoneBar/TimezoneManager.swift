import Foundation
import Combine

// MARK: - Settings Models

enum TimeFormat: String, Codable, CaseIterable, Identifiable {
    case twelve = "12h"
    case twentyFour = "24h"
    case system = "system"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twelve: return "12-hour"
        case .twentyFour: return "24-hour"
        case .system: return "System default"
        }
    }
}

/// How a timezone row in the dropdown is labelled (per-timezone setting).
enum TimezoneLabel: String, Codable, CaseIterable, Identifiable {
    case cityOnly = "city"
    case abbreviation = "abbrev"
    case utcOffset = "offset"
    case abbreviationAndOffset = "both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cityOnly: return "City name only"
        case .abbreviation: return "City + abbreviation"
        case .utcOffset: return "City + UTC offset"
        case .abbreviationAndOffset: return "City + abbreviation + offset"
        }
    }
}

/// What extra label to show next to the time in the menu bar.
enum MenuBarLabel: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case cityName = "city"
    case abbreviation = "abbrev"
    case utcOffset = "offset"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Time only"
        case .cityName: return "City name"
        case .abbreviation: return "Abbreviation (IST, WET)"
        case .utcOffset: return "UTC offset"
        }
    }
}

enum MenuBarDisplay: Codable, Equatable {
    case localTime
    case specificTimezone(String)
    case iconOnly

    var displayName: String {
        switch self {
        case .localTime: return "Local time"
        case .specificTimezone(let tz): return cityName(for: tz)
        case .iconOnly: return "Icon only"
        }
    }
}

/// Per-timezone configuration stored in the list.
struct TimezoneConfig: Codable, Equatable, Identifiable {
    var identifier: String
    var timeFormat: TimeFormat = .system
    var timezoneLabel: TimezoneLabel = .abbreviation
    var nickname: String?

    var id: String { identifier }

    /// Returns the nickname if set, otherwise the city name extracted from the identifier.
    var displayName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        return cityName(for: identifier)
    }
}

struct AppSettings: Codable, Equatable {
    var menuBarDisplay: MenuBarDisplay = .localTime
    var menuBarShowSeconds: Bool = false
    var menuBarLabel: MenuBarLabel = .none
    var includeLocalTime: Bool = true
    var timezones: [TimezoneConfig] = [
        TimezoneConfig(identifier: "UTC"),
        TimezoneConfig(identifier: "Europe/Lisbon"),
        TimezoneConfig(identifier: "Asia/Kolkata"),
    ]
}

// MARK: - TimezoneManager

final class TimezoneManager: ObservableObject {
    static let shared = TimezoneManager()

    private let userDefaults: UserDefaults
    private static let settingsKey = "AppSettings"

    @Published var settings: AppSettings {
        didSet {
            save()
        }
    }

    /// Shared singleton init — reads from standard UserDefaults.
    private convenience init() {
        self.init(userDefaults: .standard)
    }

    /// Testable init — pass any UserDefaults instance (e.g. an ephemeral suite).
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: Self.settingsKey)
        }
    }

    // MARK: - Timezone CRUD

    func addTimezone(_ identifier: String) {
        guard !settings.timezones.contains(where: { $0.identifier == identifier }) else { return }
        settings.timezones.append(TimezoneConfig(identifier: identifier))
    }

    func removeTimezone(at index: Int) {
        guard settings.timezones.indices.contains(index) else { return }
        let removed = settings.timezones.remove(at: index)
        if case .specificTimezone(let tz) = settings.menuBarDisplay, tz == removed.identifier {
            settings.menuBarDisplay = .localTime
        }
    }

    func moveTimezone(from source: Int, to destination: Int) {
        guard settings.timezones.indices.contains(source) else { return }
        let item = settings.timezones.remove(at: source)
        let dest = min(destination, settings.timezones.count)
        settings.timezones.insert(item, at: dest)
    }

    // MARK: - Time Formatting

    /// Format time for a given timezone using the specified format.
    func formattedTime(for timezoneIdentifier: String, timeFormat: TimeFormat, showSeconds: Bool, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let tz = TimeZone(identifier: timezoneIdentifier) ?? TimeZone.current

        switch timeFormat {
        case .twelve:
            formatter.dateFormat = showSeconds ? "h:mm:ss a" : "h:mm a"
        case .twentyFour:
            formatter.dateFormat = showSeconds ? "HH:mm:ss" : "HH:mm"
        case .system:
            formatter.locale = Locale.current
            formatter.timeStyle = showSeconds ? .medium : .short
        }

        formatter.timeZone = tz
        return formatter.string(from: date)
    }

    // MARK: - Menu Bar

    func menuBarText(date: Date = Date()) -> String {
        let showSec = settings.menuBarShowSeconds
        switch settings.menuBarDisplay {
        case .localTime:
            // Local time uses system format
            return formattedTime(for: TimeZone.current.identifier, timeFormat: .system, showSeconds: showSec, date: date)
        case .specificTimezone(let tzId):
            // Use that timezone's configured format if it's in the list, otherwise system
            let config = settings.timezones.first(where: { $0.identifier == tzId })
            let fmt = config?.timeFormat ?? .system
            let time = formattedTime(for: tzId, timeFormat: fmt, showSeconds: showSec, date: date)
            let tz = TimeZone(identifier: tzId) ?? TimeZone.current
            return appendMenuBarLabel(time: time, timeZone: tz, config: config ?? TimezoneConfig(identifier: tzId), date: date)
        case .iconOnly:
            return ""
        }
    }

    private func appendMenuBarLabel(time: String, timeZone: TimeZone, config: TimezoneConfig, date: Date) -> String {
        switch settings.menuBarLabel {
        case .none:
            return time
        case .cityName:
            return "\(time)  \(config.displayName)"
        case .abbreviation:
            let abbrev = normalizedAbbreviation(for: timeZone, date: date)
            return "\(time)  \(abbrev)"
        case .utcOffset:
            return "\(time)  \(utcOffsetString(for: timeZone, date: date))"
        }
    }

    // MARK: - Dropdown Menu Items

    /// The separated columns of a dropdown menu row.
    struct MenuItemComponents {
        var city: String
        var time: String
        var suffix: String   // abbreviation, offset, both, or empty
    }

    /// Components for the local time row.
    func localTimeComponents(date: Date = Date()) -> MenuItemComponents {
        let time = formattedTime(for: TimeZone.current.identifier, timeFormat: .system, showSeconds: true, date: date)
        let abbrev = normalizedAbbreviation(for: TimeZone.current, date: date)
        return MenuItemComponents(city: "Local", time: time, suffix: abbrev)
    }

    /// Components for a configured timezone row. Dropdown always shows seconds.
    func menuItemComponents(for config: TimezoneConfig, date: Date = Date()) -> MenuItemComponents {
        let time = formattedTime(for: config.identifier, timeFormat: config.timeFormat, showSeconds: true, date: date)
        let tz = TimeZone(identifier: config.identifier) ?? TimeZone.current

        let suffix: String
        switch config.timezoneLabel {
        case .cityOnly:
            suffix = ""
        case .abbreviation:
            suffix = normalizedAbbreviation(for: tz, date: date)
        case .utcOffset:
            suffix = utcOffsetString(for: tz, date: date)
        case .abbreviationAndOffset:
            let abbrev = normalizedAbbreviation(for: tz, date: date)
            let offset = utcOffsetString(for: tz, date: date)
            suffix = "\(abbrev)  \(offset)"
        }

        return MenuItemComponents(city: config.displayName, time: time, suffix: suffix)
    }
}

// MARK: - Helpers

func cityName(for identifier: String) -> String {
    if identifier == "UTC" { return "UTC" }
    let city = identifier.split(separator: "/").last.map(String.init) ?? identifier
    return city.replacingOccurrences(of: "_", with: " ")
}

/// Returns the UTC offset string, e.g. "UTC+0", "UTC+5:30", "UTC-8".
func utcOffsetString(for timeZone: TimeZone, date: Date = Date()) -> String {
    let seconds = timeZone.secondsFromGMT(for: date)
    let hours = seconds / 3600
    let minutes = abs(seconds % 3600) / 60
    if minutes == 0 {
        return "UTC\(hours >= 0 ? "+" : "")\(hours)"
    }
    return "UTC\(hours >= 0 ? "+" : "")\(hours):\(String(format: "%02d", minutes))"
}

/// Returns the timezone abbreviation, normalizing any "GMT..." references to "UTC...".
func normalizedAbbreviation(for timeZone: TimeZone, date: Date = Date()) -> String {
    let abbrev = timeZone.abbreviation(for: date) ?? ""
    if abbrev == "GMT" {
        return "UTC"
    }
    if abbrev.hasPrefix("GMT+") || abbrev.hasPrefix("GMT-") {
        return "UTC" + abbrev.dropFirst(3)
    }
    return abbrev
}
