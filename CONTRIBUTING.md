# Contributing to MiniMaxQuotaBar

Thank you for your interest in contributing!

## Code of Conduct

Please be respectful and constructive. We follow the [Contributor Covenant](https://www.contributor-covenant.org/).

## How to Contribute

### Reporting Bugs

1. Check if the bug already exists
2. Create a detailed issue with:
   - Clear title
   - Steps to reproduce
   - Expected vs actual behavior
   - macOS version
   - Screenshot if applicable

### Suggesting Features

1. Open an issue with `[Feature Request]` prefix
2. Explain the use case
3. Describe your proposed solution

### Pull Requests

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Make** your changes with clear commits
4. **Test** locally by building and running
5. **Push** to your fork
6. **Submit** a pull request

## Development Setup

```bash
# Prerequisites
- macOS 13.0+
- Xcode 15.0+
- XcodeGen

# Setup
git clone https://github.com/yourusername/minimax-quota-bar.git
cd minimax-quota-bar

# Generate project
xcodegen generate

# Build and run
open MiniMaxQuotaBar.xcodeproj
# Press Cmd+R in Xcode to run
```

## Coding Standards

- Follow Swift API Design Guidelines
- Use meaningful variable names
- Add comments for non-obvious code
- Keep functions small and focused

## Building

```bash
# Debug build
xcodegen generate
xcodebuild -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -configuration Debug build

# Release build
xcodebuild -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -configuration Release build
```

## Questions?

Open an issue for questions about contributing.
