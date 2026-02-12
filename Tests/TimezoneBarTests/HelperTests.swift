import Testing
import Foundation
@testable import TimezoneBar

@Suite("Helper Functions")
struct HelperTests {

    // MARK: - cityName

    @Test func cityNameForUTC() {
        #expect(cityName(for: "UTC") == "UTC")
    }

    @Test func cityNameExtractsLastComponent() {
        #expect(cityName(for: "Europe/Lisbon") == "Lisbon")
        #expect(cityName(for: "Asia/Kolkata") == "Kolkata")
        #expect(cityName(for: "America/Chicago") == "Chicago")
    }

    @Test func cityNameReplacesUnderscoresWithSpaces() {
        #expect(cityName(for: "America/New_York") == "New York")
        #expect(cityName(for: "America/Los_Angeles") == "Los Angeles")
        #expect(cityName(for: "Pacific/Port_Moresby") == "Port Moresby")
    }

    @Test func cityNameHandlesDeepPaths() {
        #expect(cityName(for: "America/Indiana/Indianapolis") == "Indianapolis")
        #expect(cityName(for: "America/North_Dakota/New_Salem") == "New Salem")
    }

    @Test func cityNameFallsBackToIdentifierIfNoSlash() {
        #expect(cityName(for: "GMT") == "GMT")
    }

    // MARK: - utcOffsetString

    @Test func utcOffsetZero() {
        let utc = TimeZone(identifier: "UTC")!
        let result = utcOffsetString(for: utc)
        #expect(result == "UTC+0")
    }

    @Test func utcOffsetPositiveWholeHours() {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        // Tokyo is always UTC+9 (no DST)
        let result = utcOffsetString(for: tokyo)
        #expect(result == "UTC+9")
    }

    @Test func utcOffsetNegativeWholeHours() {
        // Use a fixed date in January to avoid DST ambiguity
        let jan = DateComponents(calendar: .current, year: 2025, month: 1, day: 15).date!
        let chicago = TimeZone(identifier: "America/Chicago")!
        let result = utcOffsetString(for: chicago, date: jan)
        #expect(result == "UTC-6")
    }

    @Test func utcOffsetHalfHour() {
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!
        let result = utcOffsetString(for: kolkata)
        #expect(result == "UTC+5:30")
    }

    @Test func utcOffsetThreeQuarterHour() {
        let chatham = TimeZone(identifier: "Pacific/Chatham")!
        // Chatham is UTC+12:45 or UTC+13:45 depending on DST
        let result = utcOffsetString(for: chatham)
        #expect(result.contains(":45"))
        #expect(result.hasPrefix("UTC+"))
    }

    // MARK: - normalizedAbbreviation

    @Test func normalizedAbbreviationReplacesGMTWithUTC() {
        let utc = TimeZone(identifier: "GMT")!
        let result = normalizedAbbreviation(for: utc)
        #expect(result == "UTC")
    }

    @Test func normalizedAbbreviationReplacesGMTPlusOffset() {
        let tz = TimeZone(secondsFromGMT: 3600 * 5 + 1800)! // +5:30
        let result = normalizedAbbreviation(for: tz)
        #expect(!result.hasPrefix("GMT"))
        #expect(result.hasPrefix("UTC"))
    }

    @Test func normalizedAbbreviationReplacesGMTMinusOffset() {
        let tz = TimeZone(secondsFromGMT: -3600 * 8)! // -8
        let result = normalizedAbbreviation(for: tz)
        #expect(!result.hasPrefix("GMT"))
        #expect(result.hasPrefix("UTC"))
    }

    @Test func normalizedAbbreviationNeverContainsGMT() {
        // Regardless of what Foundation returns, our output should use UTC
        for id in ["UTC", "GMT", "Asia/Kolkata", "Asia/Tokyo", "America/Chicago"] {
            let tz = TimeZone(identifier: id)!
            let result = normalizedAbbreviation(for: tz)
            #expect(!result.hasPrefix("GMT"), "Expected no GMT prefix for \(id), got \(result)")
        }
    }

    @Test func normalizedAbbreviationPreservesNonGMTAbbreviations() {
        // CST is not GMT-prefixed, so it should pass through
        let jan = DateComponents(calendar: .current, year: 2025, month: 1, day: 15).date!
        let chicago = TimeZone(identifier: "America/Chicago")!
        let result = normalizedAbbreviation(for: chicago, date: jan)
        #expect(result == "CST")
    }
}
