import Testing
import Foundation
@testable import TimezoneBar

@Suite("AppSettings & TimezoneConfig")
struct AppSettingsTests {

    // MARK: - TimezoneConfig defaults

    @Test func timezoneConfigDefaults() {
        let config = TimezoneConfig(identifier: "America/Chicago")
        #expect(config.identifier == "America/Chicago")
        #expect(config.timeFormat == .system)
        #expect(config.timezoneLabel == .abbreviation)
    }

    @Test func timezoneConfigIdentity() {
        let config = TimezoneConfig(identifier: "UTC")
        #expect(config.id == "UTC")
    }

    // MARK: - AppSettings defaults

    @Test func appSettingsDefaults() {
        let settings = AppSettings()
        #expect(settings.menuBarDisplay == .localTime)
        #expect(settings.menuBarShowSeconds == false)
        #expect(settings.menuBarLabel == .none)
        #expect(settings.timezones.count == 3)
    }

    // MARK: - Codable round-trip

    @Test func appSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.menuBarDisplay = .specificTimezone("Asia/Kolkata")
        settings.menuBarShowSeconds = false
        settings.menuBarLabel = .abbreviation
        settings.timezones = [
            TimezoneConfig(identifier: "UTC"),
            TimezoneConfig(identifier: "America/New_York", timeFormat: .twelve, timezoneLabel: .utcOffset),
        ]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(decoded == settings)
        #expect(decoded.menuBarDisplay == .specificTimezone("Asia/Kolkata"))
        #expect(decoded.menuBarShowSeconds == false)
        #expect(decoded.menuBarLabel == .abbreviation)
        #expect(decoded.timezones.count == 2)
        #expect(decoded.timezones[1].timeFormat == .twelve)
        #expect(decoded.timezones[1].timezoneLabel == .utcOffset)
    }

    @Test func timezoneConfigRoundTrip() throws {
        let config = TimezoneConfig(identifier: "Europe/Lisbon", timeFormat: .twentyFour, timezoneLabel: .abbreviationAndOffset)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TimezoneConfig.self, from: data)
        #expect(decoded == config)
    }

    @Test func menuBarDisplayCodableLocalTime() throws {
        let display = MenuBarDisplay.localTime
        let data = try JSONEncoder().encode(display)
        let decoded = try JSONDecoder().decode(MenuBarDisplay.self, from: data)
        #expect(decoded == display)
    }

    @Test func menuBarDisplayCodableSpecificTimezone() throws {
        let display = MenuBarDisplay.specificTimezone("Asia/Tokyo")
        let data = try JSONEncoder().encode(display)
        let decoded = try JSONDecoder().decode(MenuBarDisplay.self, from: data)
        #expect(decoded == display)
    }

    @Test func menuBarDisplayCodableIconOnly() throws {
        let display = MenuBarDisplay.iconOnly
        let data = try JSONEncoder().encode(display)
        let decoded = try JSONDecoder().decode(MenuBarDisplay.self, from: data)
        #expect(decoded == display)
    }

    // MARK: - Enum display names

    @Test func timeFormatDisplayNames() {
        #expect(TimeFormat.twelve.displayName == "12-hour")
        #expect(TimeFormat.twentyFour.displayName == "24-hour")
        #expect(TimeFormat.system.displayName == "System default")
    }

    @Test func timezoneLabelDisplayNames() {
        #expect(TimezoneLabel.cityOnly.displayName == "City name only")
        #expect(TimezoneLabel.abbreviation.displayName == "City + abbreviation")
        #expect(TimezoneLabel.utcOffset.displayName == "City + UTC offset")
        #expect(TimezoneLabel.abbreviationAndOffset.displayName == "City + abbreviation + offset")
    }

    @Test func menuBarLabelDisplayNames() {
        #expect(MenuBarLabel.none.displayName == "Time only")
        #expect(MenuBarLabel.cityName.displayName == "City name")
        #expect(MenuBarLabel.abbreviation.displayName.contains("Abbreviation"))
        #expect(MenuBarLabel.utcOffset.displayName == "UTC offset")
    }

    @Test func menuBarDisplayDisplayNames() {
        #expect(MenuBarDisplay.localTime.displayName == "Local time")
        #expect(MenuBarDisplay.iconOnly.displayName == "Icon only")
        #expect(MenuBarDisplay.specificTimezone("Europe/Lisbon").displayName == "Lisbon")
    }

    // MARK: - Equatable

    @Test func appSettingsEquality() {
        let a = AppSettings()
        let b = AppSettings()
        #expect(a == b)
    }

    @Test func appSettingsInequality() {
        var a = AppSettings()
        var b = AppSettings()
        b.menuBarShowSeconds = true
        #expect(a != b)

        a.menuBarShowSeconds = true
        #expect(a == b)
    }

    // MARK: - LoginItemManager

    @Test func loginItemManagerTestableInit() {
        let mgr = LoginItemManager(initialValue: true)
        #expect(mgr.launchAtLogin == true)

        let mgr2 = LoginItemManager(initialValue: false)
        #expect(mgr2.launchAtLogin == false)
    }
}
