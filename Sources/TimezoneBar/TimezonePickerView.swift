import SwiftUI

struct TimezonePickerView: View {
    @EnvironmentObject var manager: TimezoneManager
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var allTimezones: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    private var configuredIdentifiers: Set<String> {
        Set(manager.settings.timezones.map(\.identifier))
    }

    private var filteredTimezones: [String] {
        if searchText.isEmpty {
            return allTimezones
        }
        let query = searchText.lowercased()
        return allTimezones.filter { tz in
            tz.lowercased().contains(query) ||
            cityName(for: tz).lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Timezone")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search timezones...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // List
            List(filteredTimezones, id: \.self) { tz in
                HStack {
                    VStack(alignment: .leading) {
                        Text(cityName(for: tz))
                            .font(.body)
                        Text(tz)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(currentTimePreview(for: tz))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if configuredIdentifiers.contains(tz) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button(action: {
                            manager.addTimezone(tz)
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.plain)
        }
        .frame(width: 420, height: 500)
    }

    private func currentTimePreview(for identifier: String) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: identifier)
        return formatter.string(from: Date())
    }
}
