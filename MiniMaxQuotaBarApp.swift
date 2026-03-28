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
import UserNotifications

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

/// Strong reference to the delegate to ensure it's not deallocated by ARC
private let sharedAppDelegate = AppDelegate()

/// Main entry point for the application.
/// Uses @main attribute with a static main() function for proper lifecycle management.
@main
struct MiniMaxQuotaBarApp {
    static func main() {
        let app = NSApplication.shared
        app.delegate = sharedAppDelegate
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
    private var testButton: NSButton!
    private var statusLabel: NSTextField!
    private var isShowingPlainText = false
    weak var delegate: SettingsWindowDelegate?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        // Match the Notch HUD's dark, premium aesthetic
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(white: 0.1, alpha: 1.0)

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let containerView = NSView(frame: contentView.bounds)
        containerView.autoresizingMask = [.width, .height]
        contentView.addSubview(containerView)

        // ── Branded header: App icon + name + version ──
        let headerY: CGFloat = 380 - 40 - 56 // 284

        // App icon (from bundle)
        let iconView = NSImageView(frame: NSRect(x: 32, y: headerY, width: 56, height: 56))
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            iconView.image = appIcon
        }
        containerView.addSubview(iconView)

        let appNameLabel = NSTextField(labelWithString: "MiniMax Quota Bar")
        appNameLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        appNameLabel.textColor = .white
        appNameLabel.frame = NSRect(x: 104, y: headerY + 30, width: 300, height: 26)
        containerView.addSubview(appNameLabel)

        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        versionLabel.textColor = NSColor(white: 0.6, alpha: 1.0)
        versionLabel.frame = NSRect(x: 104, y: headerY + 8, width: 300, height: 18)
        containerView.addSubview(versionLabel)

        // Separator below header
        let headerSep = NSBox(frame: NSRect(x: 32, y: 260, width: 376, height: 1))
        headerSep.boxType = .separator
        containerView.addSubview(headerSep)

        // ── API Key section ──
        let titleLabel = NSTextField(labelWithString: "API Key Configuration")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 32, y: 216, width: 376, height: 20)
        containerView.addSubview(titleLabel)

        // Description label
        let descLabel = NSTextField(wrappingLabelWithString: "Enter your MiniMax API key to display live quota usage. Your key is securely encrypted and stored in the macOS Keychain.")
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        descLabel.frame = NSRect(x: 32, y: 176, width: 376, height: 32)
        containerView.addSubview(descLabel)

        // Input field container with glass look
        let inputContainer = NSView(frame: NSRect(x: 32, y: 120, width: 376, height: 40))
        inputContainer.wantsLayer = true
        inputContainer.layer?.cornerRadius = 8
        inputContainer.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        inputContainer.layer?.borderWidth = 1
        inputContainer.layer?.borderColor = NSColor(white: 0.25, alpha: 1.0).cgColor

        // Plain text field (hidden by default)
        plainTextField = NSTextField(frame: NSRect(x: 12, y: 8, width: 318, height: 24))
        plainTextField.placeholderString = "Enter API key..."
        plainTextField.stringValue = getApiKey() ?? ""
        plainTextField.isHidden = true
        plainTextField.isBordered = false
        plainTextField.focusRingType = .none
        plainTextField.backgroundColor = .clear
        plainTextField.textColor = .white
        plainTextField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        inputContainer.addSubview(plainTextField)

        // Secure text field
        secureTextField = NSSecureTextField(frame: NSRect(x: 12, y: 8, width: 318, height: 24))
        secureTextField.placeholderString = "Enter API key..."
        secureTextField.stringValue = getApiKey() ?? ""
        secureTextField.isBordered = false
        secureTextField.focusRingType = .none
        secureTextField.backgroundColor = .clear
        secureTextField.textColor = .white
        secureTextField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        inputContainer.addSubview(secureTextField)

        // Toggle button (eye icon)
        toggleButton = NSButton(frame: NSRect(x: 338, y: 8, width: 24, height: 24))
        toggleButton.bezelStyle = .inline
        toggleButton.isBordered = false
        toggleButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Show/Hide")
        toggleButton.contentTintColor = NSColor(white: 0.7, alpha: 1.0)
        toggleButton.target = self
        toggleButton.action = #selector(toggleVisibility)
        inputContainer.addSubview(toggleButton)

        containerView.addSubview(inputContainer)

        // Status label below input
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.frame = NSRect(x: 32, y: 94, width: 376, height: 16)
        statusLabel.isHidden = true
        containerView.addSubview(statusLabel)
        
        // ── Action Buttons ──

        // Get API Key button
        let getKeyButton = NSButton(frame: NSRect(x: 26, y: 58, width: 110, height: 32))
        getKeyButton.bezelStyle = .rounded
        getKeyButton.imagePosition = .imageLeading
        if let linkImg = NSImage(systemSymbolName: "link", accessibilityDescription: nil) {
            getKeyButton.image = linkImg
        }
        getKeyButton.title = "Get API Key"
        getKeyButton.target = self
        getKeyButton.action = #selector(openGetKeyURL)
        containerView.addSubview(getKeyButton)

        // Delete button
        let deleteButton = NSButton(frame: NSRect(x: 138, y: 58, width: 90, height: 32))
        deleteButton.bezelStyle = .rounded
        deleteButton.imagePosition = .imageLeading
        if let trashImg = NSImage(systemSymbolName: "trash", accessibilityDescription: nil) {
            deleteButton.image = trashImg
        }
        deleteButton.title = "Delete"
        deleteButton.contentTintColor = NSColor.systemRed
        deleteButton.target = self
        deleteButton.action = #selector(deleteKey)
        containerView.addSubview(deleteButton)

        // Test button
        testButton = NSButton(frame: NSRect(x: 322, y: 58, width: 90, height: 32))
        testButton.bezelStyle = .rounded
        testButton.imagePosition = .imageLeading
        if let testImg = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: nil) {
            testButton.image = testImg
        }
        testButton.title = "Test"
        testButton.target = self
        testButton.action = #selector(testConnection)
        containerView.addSubview(testButton)

        // Bottom separator
        let bottomSeparator = NSBox(frame: NSRect(x: 32, y: 48, width: 376, height: 1))
        bottomSeparator.boxType = .separator
        containerView.addSubview(bottomSeparator)

        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 242, y: 12, width: 80, height: 32))
        cancelButton.bezelStyle = .rounded
        cancelButton.title = "Cancel"
        cancelButton.target = self
        cancelButton.action = #selector(cancelAction)
        containerView.addSubview(cancelButton)

        // Save button (default, prominent)
        let saveButton = NSButton(frame: NSRect(x: 328, y: 12, width: 80, height: 32))
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
            toggleButton.image = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: "Show/Hide")
        } else {
            secureTextField.stringValue = plainTextField.stringValue
            plainTextField.isHidden = true
            secureTextField.isHidden = false
            toggleButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Show/Hide")
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

        window?.makeFirstResponder(nil)

        guard !trimmedKey.isEmpty else {
            showStatus(message: "Please enter an API key first", isError: true)
            return
        }

        // Disable button and show loading state
        testButton.isEnabled = false
        testButton.title = "Testing…"
        showStatus(message: "Connecting to MiniMax API…", isError: false)

        // Temporarily save to test
        let originalKey = getApiKey()
        _ = setApiKey(trimmedKey)

        Task {
            do {
                _ = try await getQuota()
                await MainActor.run {
                    self.showStatus(message: "✓ Connection successful!", isError: false)
                    self.restoreTestButton()
                }
            } catch {
                await MainActor.run {
                    self.showStatus(
                        message: "✗ \(error.localizedDescription)",
                        isError: true
                    )
                    self.restoreTestButton()
                }
            }

            // Restore original key if different
            if let original = originalKey {
                _ = setApiKey(original)
            }
        }
    }

    private func restoreTestButton() {
        testButton.isEnabled = true
        testButton.title = "Test"
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
class AppDelegate: NSObject, NSApplicationDelegate, SettingsWindowDelegate, NotchWindowDelegate {
    
    // MARK: - Properties
    
    /// The status bar item displayed in the menu bar
    var statusItem: NSStatusItem!
    
    /// Controller for the notch-blended HUD window
    var notchController: NotchWindowController?
    
    /// Timer for auto-refreshing quota data
    var timer: Timer?
    
    /// Refresh interval in seconds (5 minutes)
    private let refreshInterval: TimeInterval = 300
    
    /// GitHub repository for update checks
    private let githubRepo = "rubenvieira/minimax-quota-bar"
    
    /// Timestamp of the last successful data refresh
    private var lastRefreshDate: Date?
    
    /// Whether a refresh is currently in progress
    private var isRefreshing = false
    
    /// Whether we've already sent a critical quota notification this session
    private var hasNotifiedCritical = false
    
    /// Number formatter with grouping separators
    private lazy var numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        return f
    }()
    
    // MARK: - NSApplicationDelegate
    
    /// Called when the app has finished launching.
    /// Sets up the status bar item, menu, and starts auto-refresh.
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        fetchQuota()
        startAutoRefresh()
        checkForUpdates()
        requestNotificationPermission()
    }
    
    /// Requests permission to send macOS notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
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
            button.toolTip = "MiniMax Quota — Loading..."
            button.target = self
            button.action = #selector(toggleHUD(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            print("setupStatusItem: target/action set")
        }
    }
    
    /// Toggles the Notch HUD window
    @objc func toggleHUD(_ sender: Any?) {
        if notchController == nil {
            notchController = NotchWindowController()
            notchController?.delegate = self
        }
        
        if notchController?.window?.isVisible == true {
            notchController?.hideHUD()
        } else {
            notchController?.showHUD()
            fetchQuota()
        }
    }
    
    /// Sets up the main menu with options
// removed setupMenu
    /// Sets up the main menu with options
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
        modalSettingsController = settingsController

        // Run modal event loop
        NSApp.runModal(for: settingsWindow)
    }

    private var modalSettingsWindow: NSWindow?
    private var modalSettingsController: SettingsWindowController?

    func closeSettings(returnCode: NSApplication.ModalResponse) {
        NSApp.stopModal(withCode: returnCode)
        modalSettingsWindow?.orderOut(nil)
        modalSettingsWindow = nil
        modalSettingsController = nil

        if returnCode == .OK || returnCode == .alertThirdButtonReturn {
            fetchQuota()
        }
    }

    // MARK: - NotchWindowDelegate
    
    func refreshRequested() {
        refresh()
    }
    
    func settingsRequested() {
        notchController?.hideHUD()
        openSettings()
    }
    
    func quitRequested() {
        quit()
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
        isRefreshing = true
        // Show refresh animation in menu bar
        let previousTitle = statusItem.button?.title
        let previousImage = statusItem.button?.image
        statusItem.button?.title = " ↻"
        
        Task {
            do {
                let quota = try await getQuota()
                await MainActor.run {
                    self.lastRefreshDate = Date()
                    self.isRefreshing = false
                    self.updateStatusItem(quota: quota)
                    self.checkCriticalQuota(quota: quota)
                }
            } catch {
                await MainActor.run {
                    self.isRefreshing = false
                    // Restore previous state if we had one
                    if let img = previousImage {
                        self.statusItem.button?.image = img
                    }
                    if let title = previousTitle, title != " ↻" {
                        self.statusItem.button?.title = title
                    }
                    self.updateStatusItemError()
                }
            }
        }
    }
    
    /// Sends a macOS notification if quota exceeds 90%
    private func checkCriticalQuota(quota: QuotaResult) {
        let intervalUsed = quota.total - quota.remaining
        let intervalPercent = quota.total > 0
            ? Int((Double(intervalUsed) / Double(quota.total)) * 100) : 0
        let weeklyUsed = quota.weeklyTotal - quota.weeklyRemaining
        let weeklyPercent = quota.weeklyTotal > 0
            ? Int((Double(weeklyUsed) / Double(quota.weeklyTotal)) * 100) : 0
        let maxPercent = max(intervalPercent, weeklyPercent)
        
        if maxPercent >= 90 && !hasNotifiedCritical {
            hasNotifiedCritical = true
            let content = UNMutableNotificationContent()
            content.title = "MiniMax Quota Critical"
            let which = intervalPercent >= weeklyPercent ? "5h interval" : "weekly"
            content.body = "Quota at \(maxPercent)% (\(which)). Consider pausing usage."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "quota-critical",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        } else if maxPercent < 80 {
            // Reset so we can notify again if it spikes back
            hasNotifiedCritical = false
        }
    }
    
    /// Returns the status color for a given usage percentage
    private func colorForPercent(_ percent: Int) -> NSColor {
        if percent > 90 {
            return .systemRed
        } else if percent > 75 {
            return .systemOrange
        } else {
            return .systemGreen
        }
    }

    /// Formats a number with grouping separators (e.g. 15000 → "15,000")
    private func fmt(_ n: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// Updates the menu bar button and dropdown menu with quota data
    /// - Parameter quota: The quota data to display
    private func updateStatusItem(quota: QuotaResult) {
        // Calculate interval usage percentage
        let intervalUsed = quota.total - quota.remaining
        let intervalPercent = quota.total > 0
            ? Int((Double(intervalUsed) / Double(quota.total)) * 100) : 0

        // Calculate weekly usage percentage
        let weeklyUsed = quota.weeklyTotal - quota.weeklyRemaining
        let weeklyPercent = quota.weeklyTotal > 0
            ? Int((Double(weeklyUsed) / Double(quota.weeklyTotal)) * 100) : 0

        // Show the worse (higher) percentage in the menu bar
        let displayPercent = max(intervalPercent, weeklyPercent)

        // Determine status symbol based on usage percentage
        let symbolName: String
        let tintColor = colorForPercent(displayPercent)
        if displayPercent > 90 {
            symbolName = "gauge.with.needle"
        } else if displayPercent > 75 {
            symbolName = "gauge.high"
        } else {
            symbolName = "gauge.medium"
        }

        if let image = createSymbolImage(named: symbolName, tintColor: tintColor) {
            statusItem.button?.image = image
        }

        statusItem.button?.title = " \(displayPercent)%"
        statusItem.button?.imagePosition = .imageLeading

        // Tooltip for hover info
        let intervalTip = "\(intervalPercent)% used (5h)"
        let weeklyTip = "\(weeklyPercent)% used (weekly)"
        statusItem.button?.toolTip = "MiniMax: \(intervalTip) · \(weeklyTip)"

        // Update HUD Window
        notchController?.update(quota: quota, colorForPercent: colorForPercent)
    }

    /// Returns a human-readable relative time string
    private func relativeTimeString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let mins = seconds / 60
        if mins < 60 { return "\(mins) min ago" }
        let hrs = mins / 60
        return "\(hrs) hr ago"
    }
    
    /// Updates status bar button to show error state
    private func updateStatusItemError() {
        if let image = createSymbolImage(
            named: "exclamationmark.triangle",
            tintColor: .systemRed
        ) {
            statusItem.button?.image = image
        }
        statusItem.button?.title = " Error"
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.toolTip = "MiniMax: Failed to fetch quota"
    }
    
    /// Creates a colored SF Symbol image for the status bar
    /// - Parameters:
    ///   - name: SF Symbol name
    ///   - tintColor: Color to apply to the symbol
    /// - Returns: Colored NSImage or nil if creation fails
    private func createSymbolImage(named name: String, tintColor: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        guard let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: "Quota"
        )?.withSymbolConfiguration(config) else {
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

// MARK: - Custom Menu Views

/// A custom NSView used as a menu item view to show a quota section
/// with an icon, title, progress bar, usage text, and reset time.
class QuotaSectionView: NSView {

    init(
        icon: String,
        title: String,
        used: Int,
        total: Int,
        percent: Int,
        resetLabel: String,
        color: NSColor,
        formatter: NumberFormatter
    ) {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 80))
        buildUI(
            icon: icon, title: title, used: used, total: total,
            percent: percent, resetLabel: resetLabel, color: color,
            formatter: formatter
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(
        icon: String, title: String, used: Int, total: Int,
        percent: Int, resetLabel: String, color: NSColor,
        formatter: NumberFormatter
    ) {
        let padding: CGFloat = 16
        let barHeight: CGFloat = 6
        let barWidth: CGFloat = 248 // 280 - 2 * 16

        // ── Section header: icon + title ──
        let headerY: CGFloat = 56
        if let symbolImage = NSImage(
            systemSymbolName: icon,
            accessibilityDescription: title
        ) {
            let iconView = NSImageView(frame: NSRect(
                x: padding, y: headerY - 1, width: 14, height: 14
            ))
            iconView.image = symbolImage
            iconView.contentTintColor = .secondaryLabelColor
            addSubview(iconView)
        }

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(
            x: padding + 18, y: headerY, width: 200, height: 16
        )
        addSubview(titleLabel)

        // Percentage badge on the right
        let percentLabel = NSTextField(
            labelWithString: "\(percent)%"
        )
        percentLabel.font = NSFont.monospacedDigitSystemFont(
            ofSize: 11, weight: .semibold
        )
        percentLabel.textColor = .labelColor
        percentLabel.alignment = .right
        percentLabel.frame = NSRect(
            x: barWidth + padding - 40, y: headerY, width: 40, height: 16
        )
        addSubview(percentLabel)

        // ── Progress bar ──
        let barY: CGFloat = 42
        let progressBar = QuotaProgressBar(
            frame: NSRect(x: padding, y: barY, width: barWidth, height: barHeight),
            percent: percent,
            color: color
        )
        addSubview(progressBar)

        // ── Usage detail line ──
        let usedStr = formatter.string(from: NSNumber(value: used)) ?? "\(used)"
        let totalStr = formatter.string(from: NSNumber(value: total)) ?? "\(total)"
        let detailLabel = NSTextField(
            labelWithString: "\(usedStr) / \(totalStr) used"
        )
        detailLabel.font = NSFont.monospacedDigitSystemFont(
            ofSize: 11, weight: .regular
        )
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.frame = NSRect(
            x: padding, y: 20, width: barWidth, height: 14
        )
        addSubview(detailLabel)

        // ── Reset time line ──
        let resetString = NSMutableAttributedString()
        let clockAttachment = NSTextAttachment()
        if let clockImg = NSImage(
            systemSymbolName: "clock",
            accessibilityDescription: "Reset time"
        ) {
            clockAttachment.image = clockImg
            // Scale the image down for inline use
            clockAttachment.bounds = CGRect(x: 0, y: -2, width: 11, height: 11)
        }
        resetString.append(NSAttributedString(attachment: clockAttachment))
        resetString.append(NSAttributedString(string: " \(resetLabel)", attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]))

        let resetLabel2 = NSTextField(labelWithString: "")
        resetLabel2.attributedStringValue = resetString
        resetLabel2.frame = NSRect(
            x: padding, y: 4, width: barWidth, height: 14
        )
        addSubview(resetLabel2)
    }
}

/// A small rounded progress bar drawn with Core Graphics.
class QuotaProgressBar: NSView {
    private var percent: Int
    private var barColor: NSColor
    private var trackColor: NSColor

    init(frame: NSRect, percent: Int, color: NSColor, trackColor: NSColor? = nil) {
        self.percent = percent
        self.barColor = color
        self.trackColor = trackColor ?? NSColor.quaternaryLabelColor
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }
    
    func update(percent: Int, color: NSColor) {
        self.percent = percent
        self.barColor = color
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        let radius = bounds.height / 2

        // Track (background)
        let trackPath = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        trackColor.setFill()
        trackPath.fill()

        // Fill
        let fillWidth = max(
            bounds.height, // minimum visible width
            bounds.width * CGFloat(min(percent, 100)) / 100.0
        )
        if percent > 0 {
            let fillRect = NSRect(
                x: 0, y: 0, width: fillWidth, height: bounds.height
            )
            let fillPath = NSBezierPath(
                roundedRect: fillRect, xRadius: radius, yRadius: radius
            )
            barColor.setFill()
            fillPath.fill()
        }
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

// MARK: - Notch HUD UI

protocol NotchWindowDelegate: AnyObject {
    func refreshRequested()
    func settingsRequested()
    func quitRequested()
}

class NotchWindowController: NSWindowController {
    weak var delegate: NotchWindowDelegate?
    
    private var backgroundView: NSView!
    
    private var intervalView: HUDSectionView!
    private var weeklyView: HUDSectionView!
    
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    convenience init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let physicalFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        let menuBarHeight = physicalFrame.maxY - visibleFrame.maxY
        let hasNotch = menuBarHeight > 24
        
        let contentHeight: CGFloat = 36
        // Extend 10px ABOVE the physical screen top so there's
        // zero chance of a visible top edge / border.
        let overshoot: CGFloat = 10
        let totalHeight = menuBarHeight + contentHeight + overshoot
        let totalWidth: CGFloat = hasNotch ? 580 : 480
        
        let x = physicalFrame.midX - (totalWidth / 2)
        let y = physicalFrame.maxY - totalHeight + overshoot
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y,
                                width: totalWidth, height: totalHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        window.level = .popUpMenu
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false  // No shadow = no visible edge
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        self.init(window: window)
        setupUI(menuBarHeight: menuBarHeight, hasNotch: hasNotch,
                overshoot: overshoot)
    }
    
    private func setupUI(menuBarHeight: CGFloat, hasNotch: Bool,
                         overshoot: CGFloat) {
        guard let contentView = window?.contentView else { return }
        
        // Solid black background — extends above screen,
        // rounded only at the bottom.
        backgroundView = NSView(frame: contentView.bounds)
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.cgColor
        backgroundView.layer?.cornerRadius = 18
        backgroundView.layer?.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner
        ]
        backgroundView.autoresizingMask = [.width, .height]
        contentView.addSubview(backgroundView)
        
        // Content area spans from just below the screen top
        // all the way to the window bottom — sections extend up
        // alongside the notch on each side.
        let contentArea = NSView()
        contentArea.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(contentArea)
        
        NSLayoutConstraint.activate([
            contentArea.leadingAnchor.constraint(
                equalTo: backgroundView.leadingAnchor),
            contentArea.trailingAnchor.constraint(
                equalTo: backgroundView.trailingAnchor),
            contentArea.topAnchor.constraint(
                equalTo: backgroundView.topAnchor,
                constant: overshoot),
            contentArea.bottomAnchor.constraint(
                equalTo: backgroundView.bottomAnchor)
        ])
        
        // Notch width — keep it tight so content hugs close
        let notchHalf: CGFloat = hasNotch ? 100 : 20
        
        // --- Left: 5h Interval ---
        intervalView = HUDSectionView(title: "5h Interval",
                                       icon: "clock.arrow.circlepath")
        contentArea.addSubview(intervalView)
        
        // --- Right: Weekly ---
        weeklyView = HUDSectionView(title: "Weekly", icon: "calendar")
        contentArea.addSubview(weeklyView)
        
        // --- Center: Action buttons under the notch ---
        let actions = setupActionsView()
        actions.translatesAutoresizingMaskIntoConstraints = false
        contentArea.addSubview(actions)
        
        NSLayoutConstraint.activate([
            // Left section — extends from top to bottom,
            // hugging close alongside the notch.
            intervalView.leadingAnchor.constraint(
                equalTo: contentArea.leadingAnchor, constant: 16),
            intervalView.trailingAnchor.constraint(
                equalTo: contentArea.centerXAnchor, constant: -notchHalf),
            intervalView.topAnchor.constraint(
                equalTo: contentArea.topAnchor, constant: 2),
            intervalView.bottomAnchor.constraint(
                equalTo: contentArea.bottomAnchor, constant: -4),
            
            // Right section — mirrors left side
            weeklyView.leadingAnchor.constraint(
                equalTo: contentArea.centerXAnchor, constant: notchHalf),
            weeklyView.trailingAnchor.constraint(
                equalTo: contentArea.trailingAnchor, constant: -16),
            weeklyView.topAnchor.constraint(
                equalTo: contentArea.topAnchor, constant: 2),
            weeklyView.bottomAnchor.constraint(
                equalTo: contentArea.bottomAnchor, constant: -4),
            
            // Action buttons — centered horizontally under
            // the notch, in the lower half of the gap.
            actions.centerXAnchor.constraint(
                equalTo: contentArea.centerXAnchor),
            actions.bottomAnchor.constraint(
                equalTo: contentArea.bottomAnchor, constant: -10)
        ])
    }
    
    // MARK: - Action Buttons (horizontal row under notch)
    
    private func setupActionsView() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        
        stack.addArrangedSubview(makeBtn(
            "arrow.clockwise", "Refresh", #selector(refreshClicked)))
        stack.addArrangedSubview(makeBtn(
            "gearshape", "Settings", #selector(settingsClicked)))
        stack.addArrangedSubview(makeBtn(
            "xmark.circle.fill", "Quit", #selector(quitClicked),
            tint: NSColor(red: 1, green: 0.35, blue: 0.35, alpha: 0.7)))
        
        return stack
    }
    
    private func makeBtn(
        _ symbol: String, _ tip: String, _ action: Selector,
        tint: NSColor = .white.withAlphaComponent(0.5)
    ) -> NSButton {
        let img = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: tip)!
            .withSymbolConfiguration(
                .init(pointSize: 12, weight: .medium))!
        let b = NSButton(image: img, target: self, action: action)
        b.isBordered = false
        b.toolTip = tip
        b.contentTintColor = tint
        return b
    }
    
    @objc private func refreshClicked() { delegate?.refreshRequested() }
    @objc private func settingsClicked() { delegate?.settingsRequested() }
    @objc private func quitClicked() { delegate?.quitRequested() }
    
    // MARK: - Show / Hide
    
    func showHUD() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            if event.keyCode == 53 { self?.hideHUD(); return nil }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in self?.hideHUD() }
    }
    
    func hideHUD() {
        window?.orderOut(nil)
        if let m = localMonitor {
            NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor {
            NSEvent.removeMonitor(m); globalMonitor = nil }
    }
    
    // MARK: - Data
    
    func update(quota: QuotaResult,
                colorForPercent: (Int) -> NSColor) {
        let iUsed = quota.total - quota.remaining
        let iPct = quota.total > 0
            ? Int(Double(iUsed) / Double(quota.total) * 100) : 0
        let ih = quota.minutesRemaining / 60
        let im = quota.minutesRemaining % 60
        let iTime = ih > 0 ? "\(ih)h \(im)m" : "\(im)m"
        intervalView.update(used: iUsed, total: quota.total,
                            percent: iPct, resetIn: iTime,
                            color: colorForPercent(iPct))
        
        let wUsed = quota.weeklyTotal - quota.weeklyRemaining
        let wPct = quota.weeklyTotal > 0
            ? Int(Double(wUsed) / Double(quota.weeklyTotal) * 100) : 0
        let wd = quota.weeklyMinutesRemaining / 1440
        let wrm = quota.weeklyMinutesRemaining % 1440
        let wh = wrm / 60
        let wTime = wd > 0 ? "\(wd)d \(wh)h"
            : (wh > 0 ? "\(wh)h \(wrm % 60)m"
               : "\(quota.weeklyMinutesRemaining)m")
        weeklyView.update(used: wUsed, total: quota.weeklyTotal,
                          percent: wPct, resetIn: wTime,
                          color: colorForPercent(wPct))
    }
}

// MARK: - HUD Section View

class HUDSectionView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let resetLabel = NSTextField(labelWithString: "")
    private var progressBar: QuotaProgressBar!
    
    init(title: String, icon: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        // Row 1: icon + title ··· percentage
        let hdr = NSStackView()
        hdr.orientation = .horizontal
        hdr.spacing = 4
        hdr.alignment = .centerY
        if let img = NSImage(systemSymbolName: icon,
                             accessibilityDescription: nil)?
            .withSymbolConfiguration(
                .init(pointSize: 9, weight: .medium)) {
            let iv = NSImageView(image: img)
            iv.contentTintColor = .white.withAlphaComponent(0.4)
            hdr.addArrangedSubview(iv)
        }
        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = .white.withAlphaComponent(0.4)
        hdr.addArrangedSubview(titleLabel)
        
        percentLabel.font = .monospacedDigitSystemFont(
            ofSize: 13, weight: .bold)
        percentLabel.textColor = .white
        percentLabel.alignment = .right
        percentLabel.setContentHuggingPriority(
            .required, for: .horizontal)
        percentLabel.setContentCompressionResistancePriority(
            .required, for: .horizontal)
        
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.distribution = .fill
        topRow.addArrangedSubview(hdr)
        topRow.addArrangedSubview(percentLabel)
        hdr.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // Row 2: progress bar
        progressBar = QuotaProgressBar(
            frame: .zero, percent: 0, color: .systemGreen,
            trackColor: .white.withAlphaComponent(0.08))
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Row 3: count ··· reset timer
        detailLabel.font = .monospacedDigitSystemFont(
            ofSize: 9, weight: .regular)
        detailLabel.textColor = .white.withAlphaComponent(0.3)
        
        resetLabel.font = .monospacedDigitSystemFont(
            ofSize: 9, weight: .regular)
        resetLabel.textColor = .white.withAlphaComponent(0.25)
        resetLabel.alignment = .right
        resetLabel.setContentHuggingPriority(
            .required, for: .horizontal)
        resetLabel.setContentCompressionResistancePriority(
            .required, for: .horizontal)
        
        let btmRow = NSStackView()
        btmRow.orientation = .horizontal
        btmRow.distribution = .fill
        btmRow.addArrangedSubview(detailLabel)
        btmRow.addArrangedSubview(resetLabel)
        detailLabel.setContentHuggingPriority(
            .defaultLow, for: .horizontal)
        
        // Assemble
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 3
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(progressBar)
        stack.addArrangedSubview(btmRow)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressBar.widthAnchor.constraint(
                equalTo: stack.widthAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 5),
            topRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            btmRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        
        titleLabel.stringValue = title
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func update(used: Int, total: Int, percent: Int,
                resetIn: String, color: NSColor) {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        let u = f.string(from: NSNumber(value: used)) ?? "\(used)"
        let t = f.string(from: NSNumber(value: total)) ?? "\(total)"
        
        percentLabel.stringValue = "\(percent)%"
        percentLabel.textColor = color
        detailLabel.stringValue = "\(u) / \(t)"
        resetLabel.stringValue = "⏱ \(resetIn)"
        progressBar.update(percent: percent, color: color)
    }
}

