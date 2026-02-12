import AppKit
import SwiftUI
import Combine

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let manager = TimezoneManager.shared
    private var timer: Timer?
    private var cancellable: AnyCancellable?
    private var preferencesWindow: NSWindow?
    private var windowDelegate: WindowDelegate?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timezones")
            button.imagePosition = .imageLeading
        }

        // Listen for settings changes
        cancellable = manager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenu()
            }
        }

        updateMenu()
        startTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMenu()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    // MARK: - Menu Construction

    private func updateMenu() {
        let now = Date()

        // Update menu bar title
        let title = manager.menuBarText(date: now)
        if let button = statusItem.button {
            if title.isEmpty {
                button.title = ""
                button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Timezones")
            } else {
                button.title = title
                button.image = nil
            }
        }

        // Build the dropdown menu
        let menu = NSMenu()
        menu.autoenablesItems = false

        let font = NSFont(name: "Helvetica", size: 13) ?? NSFont.systemFont(ofSize: 13)
        let labelFont = NSFont(name: "Helvetica", size: 11) ?? NSFont.systemFont(ofSize: 11)
        let fontAttrs: [NSAttributedString.Key: Any] = [.font: font]
        let columnGap: CGFloat = 14

        // -- Collect all row components --
        var rows: [(components: TimezoneManager.MenuItemComponents, isLocal: Bool)] = []
        if manager.settings.includeLocalTime {
            rows.append((manager.localTimeComponents(date: now), true))
        }
        for config in manager.settings.timezones {
            rows.append((manager.menuItemComponents(for: config, date: now), false))
        }

        // -- Measure max column widths in pixels --
        var maxCityWidth: CGFloat = 0
        var maxTimeWidth: CGFloat = 0
        for row in rows {
            let cityWidth = (row.components.city as NSString).size(withAttributes: fontAttrs).width
            let timeWidth = (row.components.time as NSString).size(withAttributes: fontAttrs).width
            maxCityWidth = max(maxCityWidth, cityWidth)
            maxTimeWidth = max(maxTimeWidth, timeWidth)
        }

        let timeTabStop = ceil(maxCityWidth + columnGap)
        let suffixTabStop = ceil(timeTabStop + maxTimeWidth + columnGap)

        // -- Build paragraph style with tab stops --
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.tabStops = [
            NSTextTab(textAlignment: .left, location: timeTabStop),
            NSTextTab(textAlignment: .left, location: suffixTabStop),
        ]

        // -- Create menu items --
        for row in rows {
            let c = row.components
            var text = "\(c.city)\t\(c.time)"
            if !c.suffix.isEmpty { text += "\t\(c.suffix)" }

            let attributed = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: attributed.length)
            attributed.addAttribute(.font, value: font, range: fullRange)
            attributed.addAttribute(.paragraphStyle, value: paraStyle, range: fullRange)

            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.attributedTitle = attributed
            menu.addItem(item)
        }

        if rows.isEmpty {
            let item = NSMenuItem(title: "No timezones configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            let attributed = NSMutableAttributedString(string: item.title)
            attributed.addAttribute(.font, value: labelFont, range: NSRange(location: 0, length: item.title.count))
            attributed.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: 0, length: item.title.count))
            item.attributedTitle = attributed
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let editItem = NSMenuItem(title: "Edit Timezones...", action: #selector(openPreferences(_:)), keyEquivalent: ",")
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func openPreferences(_ sender: Any?) {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let prefsView = PreferencesView()
            .environmentObject(manager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Timezone Bar Preferences"
        window.contentView = NSHostingView(rootView: prefsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        let delegate = WindowDelegate { [weak self] in
            self?.preferencesWindow = nil
            self?.windowDelegate = nil
        }
        window.delegate = delegate
        windowDelegate = delegate

        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = window
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}

// MARK: - Window Close Delegate

private final class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
