import Testing
import Foundation
@testable import TimezoneBar

@Suite("TimezoneManager")
struct TimezoneManagerTests {

    /// Creates a TimezoneManager backed by an ephemeral UserDefaults suite.
    private func makeManager() -> TimezoneManager {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return TimezoneManager(userDefaults: defaults)
    }

    /// Fixed date: 2025-01-15 14:30:45 UTC
    private let fixedDate = Date(timeIntervalSince1970: 1736951445)

    // MARK: - Default settings

    @Test func defaultSettingsHaveThreeTimezones() {
        let mgr = makeManager()
        #expect(mgr.settings.timezones.count == 3)
        #expect(mgr.settings.timezones[0].identifier == "UTC")
        #expect(mgr.settings.timezones[1].identifier == "Europe/Lisbon")
        #expect(mgr.settings.timezones[2].identifier == "Asia/Kolkata")
    }

    @Test func defaultMenuBarDisplayIsLocalTime() {
        let mgr = makeManager()
        #expect(mgr.settings.menuBarDisplay == .localTime)
    }

    @Test func defaultMenuBarShowSecondsIsFalse() {
        let mgr = makeManager()
        #expect(mgr.settings.menuBarShowSeconds == false)
    }

    @Test func defaultMenuBarLabelIsNone() {
        let mgr = makeManager()
        #expect(mgr.settings.menuBarLabel == .none)
    }

    @Test func defaultTimezoneConfigUsesSystemFormatAndAbbreviation() {
        let mgr = makeManager()
        for config in mgr.settings.timezones {
            #expect(config.timeFormat == .system)
            #expect(config.timezoneLabel == .abbreviation)
        }
    }

    // MARK: - CRUD operations

    @Test func addTimezone() {
        let mgr = makeManager()
        mgr.addTimezone("America/New_York")
        #expect(mgr.settings.timezones.count == 4)
        #expect(mgr.settings.timezones.last?.identifier == "America/New_York")
    }

    @Test func addDuplicateTimezoneIsNoOp() {
        let mgr = makeManager()
        mgr.addTimezone("UTC")
        #expect(mgr.settings.timezones.count == 3) // unchanged
    }

    @Test func removeTimezone() {
        let mgr = makeManager()
        mgr.removeTimezone(at: 1) // remove Europe/Lisbon
        #expect(mgr.settings.timezones.count == 2)
        #expect(mgr.settings.timezones[0].identifier == "UTC")
        #expect(mgr.settings.timezones[1].identifier == "Asia/Kolkata")
    }

    @Test func removeTimezoneOutOfBoundsIsNoOp() {
        let mgr = makeManager()
        mgr.removeTimezone(at: 99)
        #expect(mgr.settings.timezones.count == 3)
    }

    @Test func removeTimezoneResetsMenuBarDisplayIfNeeded() {
        let mgr = makeManager()
        mgr.settings.menuBarDisplay = .specificTimezone("Europe/Lisbon")
        mgr.removeTimezone(at: 1)
        #expect(mgr.settings.menuBarDisplay == .localTime)
    }

    @Test func removeTimezoneDoesNotResetMenuBarDisplayForOthers() {
        let mgr = makeManager()
        mgr.settings.menuBarDisplay = .specificTimezone("Asia/Kolkata")
        mgr.removeTimezone(at: 0) // remove UTC
        #expect(mgr.settings.menuBarDisplay == .specificTimezone("Asia/Kolkata"))
    }

    @Test func moveTimezoneToEnd() {
        let mgr = makeManager()
        // [UTC, Lisbon, Kolkata] -> remove UTC -> [Lisbon, Kolkata] -> insert at 2 -> [Lisbon, Kolkata, UTC]
        mgr.moveTimezone(from: 0, to: 3)
        #expect(mgr.settings.timezones[0].identifier == "Europe/Lisbon")
        #expect(mgr.settings.timezones[1].identifier == "Asia/Kolkata")
        #expect(mgr.settings.timezones[2].identifier == "UTC")
    }

    @Test func moveTimezoneToBeginning() {
        let mgr = makeManager()
        // [UTC, Lisbon, Kolkata] -> remove Kolkata -> [UTC, Lisbon] -> insert at 0 -> [Kolkata, UTC, Lisbon]
        mgr.moveTimezone(from: 2, to: 0)
        #expect(mgr.settings.timezones[0].identifier == "Asia/Kolkata")
        #expect(mgr.settings.timezones[1].identifier == "UTC")
        #expect(mgr.settings.timezones[2].identifier == "Europe/Lisbon")
    }

    @Test func moveTimezoneOutOfBoundsIsNoOp() {
        let mgr = makeManager()
        mgr.moveTimezone(from: 10, to: 0)
        #expect(mgr.settings.timezones.count == 3)
    }

    @Test func moveTimezoneClampDestination() {
        let mgr = makeManager()
        mgr.moveTimezone(from: 0, to: 100) // should clamp to end
        #expect(mgr.settings.timezones.last?.identifier == "UTC")
    }

    // MARK: - Persistence

    @Test func settingsPersistedToUserDefaults() {
        let suiteName = "test-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let mgr1 = TimezoneManager(userDefaults: defaults)
        mgr1.addTimezone("America/Chicago")
        mgr1.settings.menuBarShowSeconds = true

        let mgr2 = TimezoneManager(userDefaults: defaults)
        #expect(mgr2.settings.timezones.count == 4)
        #expect(mgr2.settings.timezones.last?.identifier == "America/Chicago")
        #expect(mgr2.settings.menuBarShowSeconds == true)
    }

    // MARK: - Time formatting

    @Test func formattedTimeTwelveHourWithSeconds() {
        let mgr = makeManager()
        let result = mgr.formattedTime(for: "UTC", timeFormat: .twelve, showSeconds: true, date: fixedDate)
        #expect(result == "2:30:45 PM")
    }

    @Test func formattedTimeTwelveHourWithoutSeconds() {
        let mgr = makeManager()
        let result = mgr.formattedTime(for: "UTC", timeFormat: .twelve, showSeconds: false, date: fixedDate)
        #expect(result == "2:30 PM")
    }

    @Test func formattedTimeTwentyFourHourWithSeconds() {
        let mgr = makeManager()
        let result = mgr.formattedTime(for: "UTC", timeFormat: .twentyFour, showSeconds: true, date: fixedDate)
        #expect(result == "14:30:45")
    }

    @Test func formattedTimeTwentyFourHourWithoutSeconds() {
        let mgr = makeManager()
        let result = mgr.formattedTime(for: "UTC", timeFormat: .twentyFour, showSeconds: false, date: fixedDate)
        #expect(result == "14:30")
    }

    @Test func formattedTimeRespectsTimezone() {
        let mgr = makeManager()
        let utcTime = mgr.formattedTime(for: "UTC", timeFormat: .twentyFour, showSeconds: false, date: fixedDate)
        let tokyoTime = mgr.formattedTime(for: "Asia/Tokyo", timeFormat: .twentyFour, showSeconds: false, date: fixedDate)
        #expect(utcTime == "14:30")
        #expect(tokyoTime == "23:30") // UTC+9
    }

    // MARK: - Menu bar text

    @Test func menuBarTextIconOnlyReturnsEmpty() {
        let mgr = makeManager()
        mgr.settings.menuBarDisplay = .iconOnly
        #expect(mgr.menuBarText() == "")
    }

    @Test func menuBarTextSpecificTimezoneWithCityLabel() {
        let mgr = makeManager()
        mgr.settings.menuBarDisplay = .specificTimezone("Asia/Kolkata")
        mgr.settings.menuBarLabel = .cityName
        mgr.settings.menuBarShowSeconds = false

        let result = mgr.menuBarText(date: fixedDate)
        #expect(result.contains("Kolkata"))
    }

    @Test func menuBarTextSpecificTimezoneWithAbbreviationLabel() {
        let mgr = makeManager()
        mgr.settings.menuBarDisplay = .specificTimezone("Asia/Kolkata")
        mgr.settings.menuBarLabel = .abbreviation
        mgr.settings.menuBarShowSeconds = false

        let result = mgr.menuBarText(date: fixedDate)
        // On this system, Kolkata abbreviation is normalized from GMT+5:30 -> UTC+5:30
        #expect(result.contains("UTC+5:30"))
    }

    @Test func menuBarTextSpecificTimezoneWithUTCOffsetLabel() {
        let mgr = makeManager()
        mgr.settings.menuBarDisplay = .specificTimezone("Asia/Kolkata")
        mgr.settings.menuBarLabel = .utcOffset
        mgr.settings.menuBarShowSeconds = false

        let result = mgr.menuBarText(date: fixedDate)
        #expect(result.contains("UTC+5:30"))
    }

    @Test func menuBarTextNoLabelShowsTimeOnly() {
        let mgr = makeManager()
        mgr.settings.menuBarDisplay = .specificTimezone("UTC")
        mgr.settings.menuBarLabel = .none
        mgr.settings.menuBarShowSeconds = false
        mgr.settings.timezones[0].timeFormat = .twentyFour

        let result = mgr.menuBarText(date: fixedDate)
        #expect(result == "14:30")
    }

    @Test func menuBarTextRespectsShowSeconds() {
        let mgr = makeManager()
        mgr.settings.menuBarDisplay = .specificTimezone("UTC")
        mgr.settings.menuBarLabel = .none
        mgr.settings.timezones[0].timeFormat = .twentyFour

        mgr.settings.menuBarShowSeconds = true
        let withSec = mgr.menuBarText(date: fixedDate)
        #expect(withSec == "14:30:45")

        mgr.settings.menuBarShowSeconds = false
        let withoutSec = mgr.menuBarText(date: fixedDate)
        #expect(withoutSec == "14:30")
    }

    // MARK: - Dropdown menu item text

    @Test func menuItemComponentsCityOnly() {
        let mgr = makeManager()
        var config = TimezoneConfig(identifier: "UTC")
        config.timeFormat = .twentyFour
        config.timezoneLabel = .cityOnly

        let c = mgr.menuItemComponents(for: config, date: fixedDate)
        #expect(c.city == "UTC")
        #expect(c.time == "14:30:45")
        #expect(c.suffix == "")
    }

    @Test func menuItemComponentsWithAbbreviation() {
        let mgr = makeManager()
        var config = TimezoneConfig(identifier: "Asia/Kolkata")
        config.timeFormat = .twentyFour
        config.timezoneLabel = .abbreviation

        let c = mgr.menuItemComponents(for: config, date: fixedDate)
        #expect(c.city == "Kolkata")
        #expect(c.time == "20:00:45")
        #expect(c.suffix == "UTC+5:30")
    }

    @Test func menuItemComponentsWithUTCOffset() {
        let mgr = makeManager()
        var config = TimezoneConfig(identifier: "Asia/Kolkata")
        config.timeFormat = .twentyFour
        config.timezoneLabel = .utcOffset

        let c = mgr.menuItemComponents(for: config, date: fixedDate)
        #expect(c.suffix == "UTC+5:30")
    }

    @Test func menuItemComponentsWithBothAbbrevAndOffset() {
        let mgr = makeManager()
        var config = TimezoneConfig(identifier: "Asia/Kolkata")
        config.timeFormat = .twentyFour
        config.timezoneLabel = .abbreviationAndOffset

        let c = mgr.menuItemComponents(for: config, date: fixedDate)
        #expect(c.city == "Kolkata")
        #expect(c.suffix.contains("UTC+5:30"))
    }

    @Test func menuItemComponentsAlwaysShowsSeconds() {
        let mgr = makeManager()
        // Dropdown always shows seconds regardless of menuBarShowSeconds
        mgr.settings.menuBarShowSeconds = false
        var config = TimezoneConfig(identifier: "UTC")
        config.timeFormat = .twentyFour
        config.timezoneLabel = .cityOnly

        let c = mgr.menuItemComponents(for: config, date: fixedDate)
        #expect(c.time == "14:30:45")
    }

    @Test func menuItemComponentsUsesNickname() {
        let mgr = makeManager()
        var config = TimezoneConfig(identifier: "Asia/Kolkata")
        config.nickname = "Office"
        config.timeFormat = .twentyFour
        config.timezoneLabel = .cityOnly

        let c = mgr.menuItemComponents(for: config, date: fixedDate)
        #expect(c.city == "Office")
    }

    @Test func localTimeComponents() {
        let mgr = makeManager()
        let c = mgr.localTimeComponents(date: fixedDate)
        #expect(c.city == "Local")
        #expect(!c.time.isEmpty)
        #expect(!c.suffix.isEmpty) // abbreviation of current timezone
    }

    // MARK: - Per-timezone format independence

    @Test func perTimezoneFormatIsIndependent() {
        let mgr = makeManager()
        mgr.settings.timezones[0].timeFormat = .twentyFour // UTC
        mgr.settings.timezones[2].timeFormat = .twelve      // Asia/Kolkata

        let utc = mgr.menuItemComponents(for: mgr.settings.timezones[0], date: fixedDate)
        let kol = mgr.menuItemComponents(for: mgr.settings.timezones[2], date: fixedDate)

        #expect(utc.time == "14:30:45")         // 24h format
        #expect(kol.time == "8:00:45 PM")       // 12h format
    }

    @Test func perTimezoneLabelIsIndependent() {
        let mgr = makeManager()
        mgr.settings.timezones[0].timezoneLabel = .cityOnly
        mgr.settings.timezones[2].timezoneLabel = .utcOffset
        mgr.settings.timezones[0].timeFormat = .twentyFour
        mgr.settings.timezones[2].timeFormat = .twentyFour

        let utc = mgr.menuItemComponents(for: mgr.settings.timezones[0], date: fixedDate)
        let kol = mgr.menuItemComponents(for: mgr.settings.timezones[2], date: fixedDate)

        #expect(utc.suffix == "")                // cityOnly = no suffix
        #expect(kol.suffix == "UTC+5:30")        // utcOffset = has offset
    }
}
