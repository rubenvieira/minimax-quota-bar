# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MiniMaxQuotaBar is a macOS menu bar app that displays MiniMax API quota usage in real-time. Single-source Swift app using AppKit.

## Build Commands

```bash
xcodegen generate  # Generate Xcode project from project.yml

# Debug build
xcodebuild -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -configuration Debug build

# Copy Debug build to /Applications
rm -rf /Applications/MiniMaxQuotaBar.app && cp -R ~/Library/Developer/Xcode/DerivedData/MiniMaxQuotaBar-*/Build/Products/Debug/MiniMaxQuotaBar.app /Applications/
```

## Architecture

All app logic is in `MiniMaxQuotaBarApp.swift` (single-file app):

**Keychain enum**: Secure API key storage via macOS Keychain

**SettingsWindowController**: Settings sheet with NSSecureTextField for API key, show/hide toggle, Get API Key/Delete/Test/Save buttons

**AppDelegate**: Menu bar lifecycle, status item, auto-refresh timer, GitHub update checking

**QuotaResult struct**: API response model with both 5h interval fields (`total`, `remaining`, `minutesRemaining`) and weekly fields (`weeklyTotal`, `weeklyRemaining`, `weeklyMinutesRemaining`)

**getQuota() async throws**: Fetches quota from MiniMax API `/v1/api/openplatform/coding_plan/remains`, parses M2.5 model data

**updateStatusItem()**: Updates menu bar button (shows worst percentage) and dropdown menu (shows both 5h and Weekly stats)

### Key Design Decisions

- Menu bar app only (`LSUIElement = YES`), no dock icon
- Auto-refresh every 5 minutes via `Timer`
- SF Symbols gauge icons with color coding: green (0-75%), yellow (75-90%), red (90-100%)
- Async/await for network, UI updates via `MainActor.run`
- Version checking against GitHub releases for auto-update prompts
