# AGENTS.md - MiniMaxQuotaBar Developer Guide

## Overview

MiniMaxQuotaBar is a macOS menu bar application that displays MiniMax API quota usage in real-time. Built with Swift 5.9, AppKit, and native macOS frameworks.

## Project Structure

```
MiniMaxQuotaBar/
├── MiniMaxQuotaBarApp.swift   # Main app code (single source file)
├── Assets.xcassets/            # App icons
├── project.yml                 # XcodeGen configuration
├── MiniMaxQuotaBar.xcodeproj/ # Generated Xcode project
├── README.md                   # User documentation
└── LICENSE                     # MIT License
```

## Build Commands

### Generate Xcode Project
```bash
xcodegen generate
```

### Build Debug
```bash
xcodebuild -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -configuration Debug build
```

### Build Release
```bash
xcodebuild -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -configuration Release build
```

### Copy to Applications (after build)
```bash
cp -R ~/Library/Developer/Xcode/DerivedData/MiniMaxQuotaBar-enccfvsfpntloqgxpjnoizmxzkde/Build/Products/Debug/MiniMaxQuotaBar.app /Applications/
```

### Rebuild & Install (Debug)
```bash
xcodebuild -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -configuration Debug build && \
cp -R ~/Library/Developer/Xcode/DerivedData/MiniMaxQuotaBar-enccfvsfpntloqgxpjnoizmxzkde/Build/Products/Debug/MiniMaxQuotaBar.app /Applications/
```

### Run App
```bash
open /Applications/MiniMaxQuotaBar.app
```

### Testing
```bash
# Run all tests
xcodebuild test -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar

# Run a single test class
xcodebuild test -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -only-testing:TestClassName

# Run a single test method
xcodebuild test -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -only-testing:TestClassName/testMethodName
```

## Code Style Guidelines

### Imports
- Group: Foundation → AppKit → Security → third-party
- Prefer specific imports over module imports
```swift
import Foundation
import AppKit
import Security
```

### Formatting
- 4 spaces for indentation
- Max line length: 100 characters
- Spaces around operators: `let x = 1 + 2`
- No trailing whitespace
- Use `// MARK: -` for organization

### Naming
- **Types/Classes/Enums**: PascalCase (`AppDelegate`, `Keychain`)
- **Functions/Methods**: camelCase (`fetchQuota()`, `updateStatusItem()`)
- **Properties/Variables**: camelCase (`statusItem`, `refreshInterval`)
- **Constants**: camelCase (`service`, `account`)
- **File names**: PascalCase (`MiniMaxQuotaBarApp.swift`)

### Type Annotations
- Prefer type inference: `let count = 0`
- Use explicit types for clarity: `let query: [String: Any] = [...]`
- Use `var` only when mutation is needed

### Access Control
- Use `private` for internal details
- Use `@discardableResult` for intentionally ignored return values

### Error Handling
- Use Swift's `throw`/`try`/`catch`
- Define custom errors with `enum` conforming to `Error`:
```swift
enum QuotaError: Error, LocalizedError {
    case noApiKey
    case apiError
    var errorDescription: String? {
        switch self {
        case .noApiKey: return "API key not configured"
        case .apiError: return "API request failed"
        }
    }
}
```
- Use `guard` for early returns on invalid conditions

### Concurrency
- Use `async`/`await` for asynchronous operations
- Use `Task` for launching async work
- Update UI on main thread with `MainActor.run` or `@MainActor`

### UI (AppKit)
- Use NSMenu for menu bar dropdowns
- Use SF Symbols for icons with custom tint colors
- Set `isEnabled = false` for read-only menu items

### Security
- Never log API keys or secrets
- Use macOS Keychain for sensitive data
- Never commit secrets to version control
- Use `.gitignore` to exclude sensitive files

### Documentation
- Use `///` for public API documentation
- Document parameters, returns, and throws

## Common Tasks

### Adding a Menu Item
1. Create `NSMenuItem` in `setupMenu()`:
```swift
let item = NSMenuItem(title: "Label", action: #selector(methodName), keyEquivalent: "key")
item.target = self
menu.addItem(item)
```
2. Add `@objc` method in `AppDelegate`:
```swift
@objc func methodName() {
    // implementation
}
```

### Adding API Key Storage
- Use `Keychain` enum for secure storage
- Call `Keychain.save(key)` to save, `Keychain.load()` to retrieve
- The Keychain uses Touch ID (biometric) authentication

### Updating Status Icons
- Located in `updateStatusItem()` method
- Use SF Symbols with `createSymbolImage()` helper
- Apply tint colors: green (0-75%), yellow (75-90%), red (90-100%)

## Version Info
- **Swift**: 5.9
- **macOS Target**: 13.0+
- **Xcode**: Use XcodeGen for project generation
