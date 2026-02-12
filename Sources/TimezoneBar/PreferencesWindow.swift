import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var manager: TimezoneManager
    @ObservedObject var loginManager = LoginItemManager.shared

    var body: some View {
        TabView {
            TimezonesTab()
                .tabItem {
                    Label("Timezones", systemImage: "globe")
                }

            GeneralTab(loginManager: loginManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 460)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @EnvironmentObject var manager: TimezoneManager
    @ObservedObject var loginManager: LoginItemManager

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $loginManager.launchAtLogin)
                    .disabled(!loginManager.isAvailable)

                if !loginManager.isAvailable {
                    Text("Launch at login requires running the app from the .app bundle.\nUse \"make install\" to install to /Applications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Menu bar display
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Menu bar shows")
                        .font(.headline)

                    radioButton(label: "Local time", tag: "__local__")
                    radioButton(label: "Icon only", tag: "__icon__")

                    if !manager.settings.timezones.isEmpty {
                        Text("Specific timezone:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        ForEach(manager.settings.timezones) { config in
                            radioButton(label: config.displayName, tag: config.identifier)
                        }
                    }
                }
            }

            Divider()

            Toggle("Show seconds", isOn: $manager.settings.menuBarShowSeconds)

            Divider()

            Section {
                Picker("Label next to time", selection: $manager.settings.menuBarLabel) {
                    ForEach(MenuBarLabel.allCases) { label in
                        Text(label.displayName).tag(label)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(manager.settings.menuBarDisplay == .iconOnly)
            }
        }
        .padding()
    }

    // Custom radio button to avoid the Divider() bug in .radioGroup pickers
    private func radioButton(label: String, tag: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: currentTag == tag ? "circle.inset.filled" : "circle")
                .foregroundColor(currentTag == tag ? .accentColor : .secondary)
                .font(.system(size: 12))
            Text(label)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            currentTag = tag
        }
    }

    private var currentTag: String {
        get {
            switch manager.settings.menuBarDisplay {
            case .localTime: return "__local__"
            case .iconOnly: return "__icon__"
            case .specificTimezone(let tz): return tz
            }
        }
        nonmutating set {
            switch newValue {
            case "__local__":
                manager.settings.menuBarDisplay = .localTime
            case "__icon__":
                manager.settings.menuBarDisplay = .iconOnly
            default:
                manager.settings.menuBarDisplay = .specificTimezone(newValue)
            }
        }
    }
}

// MARK: - Timezones Tab

struct TimezonesTab: View {
    @EnvironmentObject var manager: TimezoneManager
    @State private var showingPicker = false
    @State private var selectedIdentifier: String?

    var body: some View {
        HStack(spacing: 0) {
            // Left: timezone list (fixed width)
            VStack(alignment: .leading, spacing: 8) {
                Text("Timezones")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                List(selection: $selectedIdentifier) {
                    ForEach(Array(manager.settings.timezones.enumerated()), id: \.element.identifier) { index, config in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(config.displayName)
                                    .font(.body)
                                Text(config.identifier)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                if selectedIdentifier == config.identifier {
                                    selectedIdentifier = nil
                                }
                                manager.removeTimezone(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .tag(config.identifier)
                        .padding(.vertical, 2)
                    }
                    .onMove { source, destination in
                        if let first = source.first {
                            manager.moveTimezone(from: first, to: destination)
                        }
                    }
                }
                .listStyle(.bordered)

                HStack {
                    Button(action: { showingPicker = true }) {
                        Label("Add", systemImage: "plus")
                    }
                    Spacer()
                    Text("\(manager.settings.timezones.count) timezone(s)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal)

                Toggle("Include local time", isOn: $manager.settings.includeLocalTime)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .frame(width: 240)

            Divider()

            // Right: per-timezone settings (fills remaining space)
            VStack {
                if let id = selectedIdentifier,
                   let index = manager.settings.timezones.firstIndex(where: { $0.identifier == id }) {
                    TimezoneSettingsView(config: $manager.settings.timezones[index])
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "sidebar.right")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Select a timezone to edit its display settings")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingPicker) {
            TimezonePickerView(isPresented: $showingPicker)
                .environmentObject(manager)
        }
    }
}

// MARK: - Per-Timezone Settings (right pane)

struct TimezoneSettingsView: View {
    @Binding var config: TimezoneConfig

    var body: some View {
        Form {
            Text(config.displayName)
                .font(.headline)

            Text(config.identifier)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            TextField("Nickname", text: nicknameBinding, prompt: Text(cityName(for: config.identifier)))

            Divider()

            Picker("Time format", selection: $config.timeFormat) {
                ForEach(TimeFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.radioGroup)

            Divider()

            Picker("Display", selection: $config.timezoneLabel) {
                ForEach(TimezoneLabel.allCases) { label in
                    Text(label.displayName).tag(label)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .padding()
    }

    /// Bridges the optional `nickname` to a non-optional String for TextField.
    private var nicknameBinding: Binding<String> {
        Binding(
            get: { config.nickname ?? "" },
            set: { config.nickname = $0.isEmpty ? nil : $0 }
        )
    }
}


