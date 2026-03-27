//
//  MiniMaxQuotaBarApp.swift
//  MiniMaxQuotaBar
//
//  A macOS menu bar app that displays MiniMax API quota usage in real-time.
//  https://github.com/yourusername/minimax-quota-bar
//

import Foundation
import AppKit
import Security

// MARK: - Keychain Helper

enum Keychain {
    static let service = "com.minimax.quota-bar"
    static let account = "minimax-api-key"
    
    static func save(_ key: String) -> Bool {
        let data = Data(key.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - App Entry Point

/// Main entry point for the application.
/// Uses @main attribute with a static main() function for proper lifecycle management.
@main
struct MiniMaxQuotaBarApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

// MARK: - Settings Window Controller

protocol SettingsWindowDelegate: AnyObject {
    func settingsWindow(_ controller: SettingsWindowController, didCloseWithReturnCode returnCode: NSApplication.ModalResponse)
}

/// Controller for the API key settings window presented as a sheet
class SettingsWindowController: NSWindowController {
    private var secureTextField: NSSecureTextField!
    private var plainTextField: NSTextField!
    private var toggleButton: NSButton!
    private var statusLabel: NSTextField!
    private var isShowingPlainText = false
    weak var delegate: SettingsWindowDelegate?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let containerView = NSView(frame: contentView.bounds)
        containerView.autoresizingMask = [.width, .height]
        contentView.addSubview(containerView)

        // Title label
        let titleLabel = NSTextField(labelWithString: "API Key")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 24, y: 270, width: 432, height: 24)
        containerView.addSubview(titleLabel)

        // Description label
        let descLabel = NSTextField(wrappingLabelWithString: "Enter your MiniMax API key. The key will be stored securely in macOS Keychain with Touch ID protection.")
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = NSColor.secondaryLabelColor
        descLabel.frame = NSRect(x: 24, y: 235, width: 432, height: 36)
        containerView.addSubview(descLabel)

        // Input field container with styled border
        let inputContainer = NSView(frame: NSRect(x: 24, y: 185, width: 432, height: 40))
        inputContainer.wantsLayer = true
        inputContainer.layer?.cornerRadius = 8
        inputContainer.layer?.borderWidth = 1
        inputContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        inputContainer.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        // Plain text field (hidden by default)
        plainTextField = NSTextField(frame: NSRect(x: 12, y: 6, width: 370, height: 28))
        plainTextField.placeholderString = "Enter API key..."
        plainTextField.stringValue = getApiKey() ?? ""
        plainTextField.isHidden = true
        plainTextField.isBordered = false
        plainTextField.backgroundColor = .clear
        plainTextField.font = NSFont.systemFont(ofSize: 13)
        inputContainer.addSubview(plainTextField)

        // Secure text field
        secureTextField = NSSecureTextField(frame: NSRect(x: 12, y: 6, width: 370, height: 28))
        secureTextField.placeholderString = "Enter API key..."
        secureTextField.stringValue = getApiKey() ?? ""
        secureTextField.isBordered = false
        secureTextField.backgroundColor = .clear
        secureTextField.font = NSFont.systemFont(ofSize: 13)
        inputContainer.addSubview(secureTextField)

        // Toggle button (eye icon)
        toggleButton = NSButton(frame: NSRect(x: 385, y: 4, width: 32, height: 32))
        toggleButton.bezelStyle = .inline
        toggleButton.isBordered = false
        toggleButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Show/Hide")
        toggleButton.contentTintColor = NSColor.secondaryLabelColor
        toggleButton.target = self
        toggleButton.action = #selector(toggleVisibility)
        inputContainer.addSubview(toggleButton)

        containerView.addSubview(inputContainer)

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.frame = NSRect(x: 24, y: 158, width: 432, height: 20)
        statusLabel.isHidden = true
        containerView.addSubview(statusLabel)

        // Separator
        let separator = NSBox(frame: NSRect(x: 24, y: 140, width: 432, height: 1))
        separator.boxType = .separator
        containerView.addSubview(separator)

        // Buttons row with icons
        let buttonY: CGFloat = 88

        // Get API Key button with icon
        let getKeyButton = NSButton(frame: NSRect(x: 24, y: buttonY, width: 130, height: 32))
        getKeyButton.bezelStyle = .rounded
        getKeyButton.image = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: nil)
        getKeyButton.imagePosition = .imageLeading
        getKeyButton.title = "Get API Key"
        getKeyButton.target = self
        getKeyButton.action = #selector(openGetKeyURL)
        containerView.addSubview(getKeyButton)

        // Delete button with icon
        let deleteButton = NSButton(frame: NSRect(x: 162, y: buttonY, width: 120, height: 32))
        deleteButton.bezelStyle = .rounded
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        deleteButton.imagePosition = .imageLeading
        deleteButton.title = "Delete"
        deleteButton.contentTintColor = NSColor.systemRed
        deleteButton.target = self
        deleteButton.action = #selector(deleteKey)
        containerView.addSubview(deleteButton)

        // Test button with icon
        let testButton = NSButton(frame: NSRect(x: 290, y: buttonY, width: 90, height: 32))
        testButton.bezelStyle = .rounded
        testButton.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: nil)
        testButton.imagePosition = .imageLeading
        testButton.title = "Test"
        testButton.target = self
        testButton.action = #selector(testConnection)
        containerView.addSubview(testButton)

        // Bottom separator
        let bottomSeparator = NSBox(frame: NSRect(x: 24, y: 70, width: 432, height: 1))
        bottomSeparator.boxType = .separator
        containerView.addSubview(bottomSeparator)

        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 300, y: 24, width: 80, height: 32))
        cancelButton.bezelStyle = .rounded
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(cancelAction)
        containerView.addSubview(cancelButton)

        // Save button (default, prominent)
        let saveButton = NSButton(frame: NSRect(x: 388, y: 24, width: 68, height: 32))
        saveButton.bezelStyle = .rounded
        saveButton.title = "Save"
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveAction)
        containerView.addSubview(saveButton)
    }

    @objc private func toggleVisibility() {
        isShowingPlainText.toggle()

        if isShowingPlainText {
            plainTextField.stringValue = secureTextField.stringValue
            secureTextField.isHidden = true
            plainTextField.isHidden = false
            toggleButton.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Show/Hide")
        } else {
            secureTextField.stringValue = plainTextField.stringValue
            plainTextField.isHidden = true
            secureTextField.isHidden = false
            toggleButton.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Show/Hide")
        }
    }

    @objc private func openGetKeyURL() {
        NSWorkspace.shared.open(URL(string: "https://platform.minimax.io/user-center/payment/token-plan")!)
    }

    @objc private func deleteKey() {
        removeApiKey()
        secureTextField.stringValue = ""
        plainTextField.stringValue = ""
        showStatus(message: "API key deleted", isError: false)
    }

    @objc private func testConnection() {
        let apiKey = isShowingPlainText ? plainTextField.stringValue : secureTextField.stringValue
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        showStatus(message: "Testing with key: \(trimmedKey.prefix(5))...", isError: false)
        window?.makeFirstResponder(nil)

        guard !trimmedKey.isEmpty else {
            showStatus(message: "Please enter an API key first", isError: true)
            return
        }

        // Temporarily save to test
        let originalKey = getApiKey()
        _ = setApiKey(trimmedKey)

        // Use semaphore to wait for async result while allowing event processing
        let semaphore = DispatchSemaphore(value: 0)
        var testResult: Result<Void, Error> = .success(())

        Task {
            do {
                _ = try await getQuota()
                testResult = .success(())
            } catch {
                testResult = .failure(error)
            }
            semaphore.signal()
        }

        // Pump the event loop while waiting
        while semaphore.wait(timeout: .now() + 0.1) == .timedOut {
            if let event = NSApp.nextEvent(matching: .any, until: Date(timeIntervalSinceNow: 0.01), inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }

        // Process result
        switch testResult {
        case .success:
            showStatus(message: "Connection successful!", isError: false)
        case .failure(let error):
            showStatus(message: "Connection failed: \(error.localizedDescription)", isError: true)
        }

        // Restore original key if different
        if let original = originalKey {
            _ = setApiKey(original)
        }
    }

    @objc private func cancelAction() {
        delegate?.settingsWindow(self, didCloseWithReturnCode: .cancel)
    }

    @objc private func saveAction() {
        let apiKey = isShowingPlainText ? plainTextField.stringValue : secureTextField.stringValue
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            showStatus(message: "Please enter an API key", isError: true)
            return
        }

        if setApiKey(trimmedKey) {
            delegate?.settingsWindow(self, didCloseWithReturnCode: .OK)
        } else {
            showStatus(message: "Failed to save API key", isError: true)
        }
    }

    private func showStatus(message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? NSColor.systemRed : NSColor.systemGreen
        statusLabel.isHidden = false
    }
}

// MARK: - AppDelegate

/// Application delegate responsible for managing the menu bar item and app lifecycle.
class AppDelegate: NSObject, NSApplicationDelegate, SettingsWindowDelegate {
    
    // MARK: - Properties
    
    /// The status bar item displayed in the menu bar
    var statusItem: NSStatusItem!
    
    /// Timer for auto-refreshing quota data
    var timer: Timer?
    
    /// Refresh interval in seconds (5 minutes)
    private let refreshInterval: TimeInterval = 300
    
    /// GitHub repository for update checks
    private let githubRepo = "rubenvieira/minimax-quota-bar"
    
    // MARK: - NSApplicationDelegate
    
    /// Called when the app has finished launching.
    /// Sets up the status bar item, menu, and starts auto-refresh.
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        setupMenu()
        fetchQuota()
        startAutoRefresh()
        checkForUpdates()
    }
    
    /// Checks GitHub for a new release and prompts user if available
    private func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else { return }
                
                let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                
                if self.isNewerVersion(latestVersion, than: currentVersion) {
                    await MainActor.run {
                        self.showUpdateAlert(newVersion: latestVersion, releaseInfo: json)
                    }
                }
            } catch {
                // Silently fail - update check is non-critical
            }
        }
    }
    
    /// Compares two version strings
    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(newParts.count, currentParts.count) {
            let newVal = i < newParts.count ? newParts[i] : 0
            let currentVal = i < currentParts.count ? currentParts[i] : 0
            if newVal > currentVal { return true }
            if newVal < currentVal { return false }
        }
        return false
    }
    
    /// Shows alert prompting user to update
    private func showUpdateAlert(newVersion: String, releaseInfo: [String: Any]) {
        guard let assets = releaseInfo["assets"] as? [[String: Any]],
              let downloadURL = (assets.first { ($0["name"] as? String)?.contains(".zip") == true })?["browser_download_url"] as? String else {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version (\(newVersion)) is available. Would you like to download and install it?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download & Install")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            downloadAndInstallUpdate(from: downloadURL)
        }
    }
    
    /// Downloads and installs the update
    private func downloadAndInstallUpdate(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        statusItem.button?.title = "⬇️ Updating..."
        
        Task {
            do {
                let (tempURL, response) = try await URLSession.shared.download(for: URLRequest(url: url))
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    await MainActor.run { self.statusItem.button?.title = "❌" }
                    return
                }
                
                let zipPath = FileManager.default.temporaryDirectory.appendingPathComponent("MiniMaxQuotaBar.zip")
                try? FileManager.default.removeItem(at: zipPath)
                try FileManager.default.moveItem(at: tempURL, to: zipPath)
                
                let extractPath = FileManager.default.temporaryDirectory.appendingPathComponent("MiniMaxQuotaBar")
                try? FileManager.default.removeItem(at: extractPath)
                
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                task.arguments = ["-o", zipPath.path, "-d", extractPath.path]
                try task.run()
                task.waitUntilExit()
                
                let appPath = extractPath.appendingPathComponent("MiniMaxQuotaBar.app")
                
                if FileManager.default.fileExists(atPath: appPath.path) {
                    await MainActor.run {
                        NSWorkspace.shared.open(appPath)
                        NSApplication.shared.terminate(nil)
                    }
                }
            } catch {
                await MainActor.run { self.statusItem.button?.title = "❌" }
            }
        }
    }
    
    // MARK: - Setup Methods
    
    /// Creates and configures the status bar item
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "⏳"  // Loading indicator
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        }
    }
    
    /// Sets up the dropdown menu with options
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        // Edit menu
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = NSMenu(title: "Edit")
        mainMenu.addItem(editMenuItem)

        let editMenu = editMenuItem.submenu!
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        NSApp.mainMenu = mainMenu
    }

    private func setupMenu() {
        let menu = NSMenu()
        
        // Header
        let titleItem = NSMenuItem(title: "MiniMax Quota", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Refresh option
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.toolTip = "Refresh quota data"
        menu.addItem(refreshItem)
        
        // Settings option
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.toolTip = "Configure API key and preferences"
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.toolTip = "Quit the application"
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    /// Starts the auto-refresh timer
    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.fetchQuota()
        }
    }
    
    // MARK: - Actions
    
    /// Manually refreshes quota data
    @objc func refresh() {
        fetchQuota()
    }
    
    /// Opens settings window as a sheet to configure API key
    @objc func openSettings() {
        let settingsController = SettingsWindowController()
        settingsController.delegate = self

        guard let settingsWindow = settingsController.window else { return }

        // Position at screen center for menu bar app
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = settingsWindow.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            settingsWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }

        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeFirstResponder(nil)

        // Store reference
        modalSettingsWindow = settingsWindow

        // Run modal event loop
        NSApp.runModal(for: settingsWindow)
    }

    private var modalSettingsWindow: NSWindow?

    func closeSettings(returnCode: NSApplication.ModalResponse) {
        NSApp.stopModal(withCode: returnCode)
        modalSettingsWindow?.orderOut(nil)
        modalSettingsWindow = nil

        if returnCode == .OK || returnCode == .alertThirdButtonReturn {
            fetchQuota()
        }
    }

    // MARK: - SettingsWindowDelegate

    func settingsWindow(_ controller: SettingsWindowController, didCloseWithReturnCode returnCode: NSApplication.ModalResponse) {
        closeSettings(returnCode: returnCode)
    }
    
    /// Quits the application
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// Dummy action for informational menu items (prevents macOS from greying them out)
    @objc private func noAction() {}
    
    // MARK: - Quota Management
    
    /// Fetches quota data from the MiniMax API
    private func fetchQuota() {
        Task {
            do {
                let quota = try await getQuota()
                await MainActor.run {
                    updateStatusItem(quota: quota)
                }
            } catch {
                await MainActor.run {
                    updateStatusItemError()
                }
            }
        }
    }
    
    /// Updates the menu bar button and dropdown menu with quota data
    /// - Parameter quota: The quota data to display
    private func updateStatusItem(quota: QuotaResult) {
        // Calculate interval usage percentage
        let intervalUsed = quota.total - quota.remaining
        let intervalPercent = quota.total > 0 ? Int((Double(intervalUsed) / Double(quota.total)) * 100) : 0

        // Calculate weekly usage percentage
        let weeklyUsed = quota.weeklyTotal - quota.weeklyRemaining
        let weeklyPercent = quota.weeklyTotal > 0 ? Int((Double(weeklyUsed) / Double(quota.weeklyTotal)) * 100) : 0

        // Show the worse (higher) percentage in the menu bar
        let displayPercent = max(intervalPercent, weeklyPercent)

        // Determine status symbol based on usage percentage
        let symbolName: String
        let tintColor: NSColor
        if displayPercent > 90 {
            symbolName = "gauge.with.needle"
            tintColor = NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        } else if displayPercent > 75 {
            symbolName = "gauge.high"
            tintColor = NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
        } else {
            symbolName = "gauge.medium"
            tintColor = NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
        }

        if let image = createSymbolImage(named: symbolName, tintColor: tintColor) {
            statusItem.button?.image = image
        }
        statusItem.button?.title = " \(displayPercent)%"
        statusItem.button?.imagePosition = .imageLeading

        // Build a new menu with quota info
        let menu = NSMenu()

        // Header
        let titleItem = NSMenuItem()
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13)
        ]
        titleItem.attributedTitle = NSAttributedString(string: "MiniMax Quota", attributes: titleAttrs)
        titleItem.action = #selector(noAction)
        titleItem.target = self
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // 5h interval section
        let intervalHeader = NSMenuItem(title: "5h Interval", action: #selector(noAction), keyEquivalent: "")
        intervalHeader.target = self
        menu.addItem(intervalHeader)

        let hours = quota.minutesRemaining / 60
        let minutes = quota.minutesRemaining % 60
        let intervalTimeString = hours > 0 ? "\(hours) hr \(minutes) min" : "\(minutes) min"
        let intervalUsedItem = NSMenuItem(title: "  • Used: \(intervalUsed) / \(quota.total) (\(intervalPercent)%)", action: #selector(noAction), keyEquivalent: "")
        intervalUsedItem.target = self
        menu.addItem(intervalUsedItem)

        let intervalTimeItem = NSMenuItem(title: "  • Resets: in \(intervalTimeString)", action: #selector(noAction), keyEquivalent: "")
        intervalTimeItem.target = self
        menu.addItem(intervalTimeItem)

        menu.addItem(NSMenuItem.separator())

        // Weekly section
        let weeklyHeader = NSMenuItem(title: "Weekly", action: #selector(noAction), keyEquivalent: "")
        weeklyHeader.target = self
        menu.addItem(weeklyHeader)

        let weeklyDays = quota.weeklyMinutesRemaining / (24 * 60)
        let weeklyRemainingMinutes = quota.weeklyMinutesRemaining % (24 * 60)
        let weeklyHours = weeklyRemainingMinutes / 60
        var weeklyTimeString: String
        if weeklyDays > 0 {
            weeklyTimeString = "\(weeklyDays) day \(weeklyHours) hr"
        } else if weeklyHours > 0 {
            weeklyTimeString = "\(weeklyHours) hr \(quota.weeklyMinutesRemaining % 60) min"
        } else {
            weeklyTimeString = "\(quota.weeklyMinutesRemaining) min"
        }
        let weeklyUsedItem = NSMenuItem(title: "  • Used: \(weeklyUsed) / \(quota.weeklyTotal) (\(weeklyPercent)%)", action: #selector(noAction), keyEquivalent: "")
        weeklyUsedItem.target = self
        menu.addItem(weeklyUsedItem)

        let weeklyTimeItem = NSMenuItem(title: "  • Resets: in \(weeklyTimeString)", action: #selector(noAction), keyEquivalent: "")
        weeklyTimeItem.target = self
        menu.addItem(weeklyTimeItem)

        menu.addItem(NSMenuItem.separator())

        // Refresh option
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        // Settings option
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Assign the new menu
        statusItem.menu = menu
    }
    
    /// Updates status bar button to show error state
    private func updateStatusItemError() {
        if let image = createSymbolImage(named: "exclamationmark.triangle", tintColor: NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)) {
            statusItem.button?.image = image
        }
        statusItem.button?.title = " Error"
        statusItem.button?.imagePosition = .imageLeading
    }
    
    /// Creates a colored SF Symbol image for the status bar
    /// - Parameters:
    ///   - name: SF Symbol name
    ///   - tintColor: Color to apply to the symbol
    /// - Returns: Colored NSImage or nil if creation fails
    private func createSymbolImage(named name: String, tintColor: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: "Quota")?.withSymbolConfiguration(config) else {
            return nil
        }
        
        let coloredImage = image.copy() as! NSImage
        coloredImage.lockFocus()
        tintColor.set()
        let imageRect = NSRect(origin: .zero, size: coloredImage.size)
        imageRect.fill(using: .sourceAtop)
        coloredImage.unlockFocus()
        
        return coloredImage
    }
}

// MARK: - Data Models

/// Represents the MiniMax API quota information
struct QuotaResult {
    /// Total quota available in the current 5-hour interval
    let total: Int

    /// Remaining quota in the current 5-hour interval
    let remaining: Int

    /// Minutes until the 5-hour interval resets
    let minutesRemaining: Int

    /// Total weekly quota available
    let weeklyTotal: Int

    /// Remaining weekly quota
    let weeklyRemaining: Int

    /// Minutes until the weekly quota resets
    let weeklyMinutesRemaining: Int
}

/// Errors that can occur when fetching quota
enum QuotaError: Error, LocalizedError {
    case noApiKey
    case apiError
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "No API key found"
        case .apiError:
            return "API request failed"
        case .parseError:
            return "Failed to parse API response"
        }
    }
}

// MARK: - API Methods

/// Retrieves the API key from secure storage.
///
/// - Returns: The API key if found in Keychain, nil otherwise
func getApiKey() -> String? {
    return Keychain.load()
}

/// Saves the API key securely to macOS Keychain.
///
/// - Parameter key: The API key to store
/// - Returns: True if successful, false otherwise
@discardableResult
func setApiKey(_ key: String) -> Bool {
    return Keychain.save(key)
}

/// Removes the API key from Keychain.
///
/// - Returns: True if successful, false otherwise
@discardableResult
func removeApiKey() -> Bool {
    return Keychain.delete()
}

/// Fetches the current quota from the MiniMax API.
///
/// - Returns: QuotaResult containing quota information
/// - Throws: QuotaError if the request fails or response cannot be parsed
func getQuota() async throws -> QuotaResult {
    // Get API key
    guard let apiKey = getApiKey() else {
        throw QuotaError.noApiKey
    }
    
    // Make API request
    let url = URL(string: "https://www.minimax.io/v1/api/openplatform/coding_plan/remains")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // Check response status
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw QuotaError.apiError
    }
    
    // Parse JSON response
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let modelRemains = json["model_remains"] as? [[String: Any]],
          // Prefer M2.5 model, fallback to first available model
          let m25 = modelRemains.first(where: { ($0["model_name"] as? String)?.contains("M2.5") ?? false }) ?? modelRemains.first else {
        throw QuotaError.parseError
    }
    
    // Extract quota data
    let total = m25["current_interval_total_count"] as? Int ?? 0
    let remaining = m25["current_interval_usage_count"] as? Int ?? 0
    let remainsTime = m25["remains_time"] as? Int ?? 0
    let minutesRemaining = remainsTime / 1000 / 60

    // Extract weekly quota data (note: *_usage_count fields are actually remaining quota)
    let weeklyTotal = m25["current_weekly_total_count"] as? Int ?? 0
    let weeklyRemaining = m25["current_weekly_usage_count"] as? Int ?? 0  // counterintuitive naming
    let weeklyRemainsTime = m25["weekly_remains_time"] as? Int ?? 0
    let weeklyMinutesRemaining = weeklyRemainsTime / 1000 / 60

    return QuotaResult(
        total: total,
        remaining: remaining,
        minutesRemaining: minutesRemaining,
        weeklyTotal: weeklyTotal,
        weeklyRemaining: weeklyRemaining,
        weeklyMinutesRemaining: weeklyMinutesRemaining
    )
}
