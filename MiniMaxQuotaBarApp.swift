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
    static let service = "com.opencode.minimax-quota-bar"
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
import AppKit

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

// MARK: - AppDelegate

/// Application delegate responsible for managing the menu bar item and app lifecycle.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// The status bar item displayed in the menu bar
    var statusItem: NSStatusItem!
    
    /// Timer for auto-refreshing quota data
    var timer: Timer?
    
    /// Refresh interval in seconds (5 minutes)
    private let refreshInterval: TimeInterval = 300
    
    // MARK: - NSApplicationDelegate
    
    /// Called when the app has finished launching.
    /// Sets up the status bar item, menu, and starts auto-refresh.
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        fetchQuota()
        startAutoRefresh()
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
    
    /// Opens settings dialog to configure API key
    @objc func openSettings() {
        let alert = NSAlert()
        alert.messageText = "MiniMax API Key"
        alert.informativeText = "Enter your MiniMax API key. The key will be stored securely in macOS Keychain."
        alert.alertStyle = .informational
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = "Enter API key..."
        inputField.stringValue = getApiKey() ?? ""
        alert.accessoryView = inputField
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let apiKey = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !apiKey.isEmpty {
                if setApiKey(apiKey) {
                    fetchQuota()
                } else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Error"
                    errorAlert.informativeText = "Failed to save API key to Keychain."
                    errorAlert.alertStyle = .warning
                    errorAlert.runModal()
                }
            }
        }
    }
    
    /// Quits the application
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
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
                    statusItem.button?.title = "❌"
                }
            }
        }
    }
    
    /// Updates the menu bar button and dropdown menu with quota data
    /// - Parameter quota: The quota data to display
    private func updateStatusItem(quota: QuotaResult) {
        let used = quota.total - quota.remaining
        let percent = Int((Double(used) / Double(quota.total)) * 100)
        
        // Determine status emoji based on usage percentage
        var emoji = "🟢"  // Healthy (0-75%)
        if percent > 90 {
            emoji = "🔴"  // Critical (90-100%)
        } else if percent > 75 {
            emoji = "🟡"  // Warning (75-90%)
        }
        
        // Update menu bar button
        statusItem.button?.title = "\(emoji) \(percent)%"
        
        // Update dropdown menu with details
        if let menu = statusItem.menu {
            // Remove old quota items
            menu.items.removeAll { item in
                item.title.contains("Used:") ||
                item.title.contains("Remaining:") ||
                item.title.contains("Resets:")
            }
            
            // Add Used count
            let usedItem = NSMenuItem(title: "Used: \(used) / \(quota.total)", action: nil, keyEquivalent: "")
            usedItem.isEnabled = false
            menu.insertItem(usedItem, at: 2)
            
            // Add Remaining count
            let remainingItem = NSMenuItem(title: "Remaining: \(quota.remaining)", action: nil, keyEquivalent: "")
            remainingItem.isEnabled = false
            menu.insertItem(remainingItem, at: 3)
            
            // Add Reset time
            let hours = quota.minutesRemaining / 60
            let minutes = quota.minutesRemaining % 60
            let timeString = hours > 0 ? "\(hours) hr \(minutes) min" : "\(minutes) min"
            
            let resetsItem = NSMenuItem(title: "Resets: in \(timeString)", action: nil, keyEquivalent: "")
            resetsItem.isEnabled = false
            menu.insertItem(resetsItem, at: 4)
            
            menu.insertItem(NSMenuItem.separator(), at: 5)
        }
    }
}

// MARK: - Data Models

/// Represents the MiniMax API quota information
struct QuotaResult {
    /// Total quota available in the current period
    let total: Int
    
    /// Remaining quota in the current period
    let remaining: Int
    
    /// Minutes until the quota resets
    let minutesRemaining: Int
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
/// Priority:
/// 1. macOS Keychain (recommended)
/// 2. `~/.config/opencode/minimax-key.txt` file
/// 3. `MINIMAX_API_KEY` environment variable
///
/// - Returns: The API key if found, nil otherwise
func getApiKey() -> String? {
    // Try Keychain first (most secure)
    if let key = Keychain.load() {
        return key
    }
    
    // Fall back to file
    let keyPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/opencode/minimax-key.txt")
    
    if let key = try? String(contentsOf: keyPath, encoding: .utf8) {
        return key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    // Fall back to environment variable
    if let key = ProcessInfo.processInfo.environment["MINIMAX_API_KEY"] {
        return key
    }
    
    return nil
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
    
    return QuotaResult(
        total: total,
        remaining: remaining,
        minutesRemaining: minutesRemaining
    )
}
