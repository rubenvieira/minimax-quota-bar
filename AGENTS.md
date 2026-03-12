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
cp -R ~/Library/Developer/Xcode/DerivedData/MiniMaxQuotaBar-*/Build/Products/Debug/MiniMaxQuotaBar.app /Applications/
```

### Run App
```bash
open /Applications/MiniMaxQuotaBar.app
```

## Code Style Guidelines

### Imports

- Group imports by framework: `Foundation`, `AppKit`, third-party
- Prefer specific imports over module imports when possible
- Order: standard library → system frameworks → third-party

```swift
import Foundation
import AppKit
import Security
```

### Formatting

- Use 4 spaces for indentation (Swift standard)
- Maximum line length: 100 characters
- Add spaces around operators: `let x = 1 + 2`
- No trailing whitespace
- Use `// MARK: -` for code organization

### Naming Conventions

- **Types/Classes/Enums**: PascalCase (`AppDelegate`, `Keychain`, `QuotaResult`)
- **Functions/Methods**: camelCase (`fetchQuota()`, `updateStatusItem()`)
- **Properties/Variables**: camelCase (`statusItem`, `refreshInterval`)
- **Constants**: camelCase or PascalCase for static enums (`service`, `account`)
- **File names**: PascalCase matching primary type (`MiniMaxQuotaBarApp.swift`)

### Type Annotations

- Prefer type inference for simple cases: `let count = 0`
- Use explicit types for clarity in dictionaries/arrays:
  ```swift
  let query: [String: Any] = [...]
  let items: [String] = []
  ```
- Use `var` only when mutation is needed

### Access Control

- Use `private` for internal implementation details
- Use `internal` (default) for APIs used within the module
- Use `@discardableResult` for functions that return values that may be intentionally ignored

### Error Handling

- Use Swift's native error handling with `throw`/`try`/`catch`
- Define custom errors with `enum` conforming to `Error`:
  ```swift
  enum QuotaError: Error, LocalizedError {
      case noApiKey
      case apiError
      case parseError
      
      var errorDescription: String? {
          switch self {
          case .noApiKey: return "API key not configured"
          case .apiError: return "API request failed"
          case .parseError: return "Failed to parse response"
          }
      }
  }
  ```
- Use `guard` for early returns on invalid conditions

### Documentation

- Use triple-slash `///` for public API documentation
- Document parameters, returns, and throws:
  ```swift
  /// Fetches the current quota from the MiniMax API.
  ///
  /// - Returns: QuotaResult containing quota information
  /// - Throws: QuotaError if the request fails or response cannot be parsed
  func getQuota() async throws -> QuotaResult
  ```
- Keep documentation concise but informative

### Concurrency

- Use `async`/`await` for asynchronous operations
- Use `Task` for launching async work
- Update UI on main thread with `MainActor.run` or `@MainActor`

### UI (AppKit)

- Use NSMenu for menu bar dropdowns
- Configure button image/title with `imagePosition = .imageLeading`
- Use SF Symbols for icons with custom tint colors
- Set `isEnabled = false` for read-only menu items

### Security

- Never log API keys or secrets
- Use macOS Keychain for sensitive data storage
- Never commit secrets to version control
- Use `.gitignore` to exclude sensitive files

### Testing

- Currently no tests exist
- When adding tests, place in a `Tests/` directory
- Follow XCTest conventions
- Test async functions with `XCTestExpectation`

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

1. Use the `Keychain` enum for secure storage
2. Call `setApiKey()` to save, `getApiKey()` to retrieve
3. Never store keys in plain text files or environment variables in production

### Updating Status Icons

- Located in `updateStatusItem()` method
- Use SF Symbols with `createSymbolImage()` helper
- Apply tint colors for different states (green/yellow/red)

## Version Info

- **Swift**: 5.9
- **macOS Target**: 13.0+
- **Xcode**: Use XcodeGen for project generation
