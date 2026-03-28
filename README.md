# MiniMaxQuotaBar

A premium macOS menu bar app that displays your MiniMax API quota usage in real-time. 
Designed with modern MacBooks in mind, MiniMaxQuotaBar features a stunning **Zero-Border Notch HUD** that flawlessly blends with your MacBook's physical hardware notch, making the app feel like a native macOS system extension.

![macOS Menu Bar](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- 💻 **Zero-Border Notch HUD** - Click the menu bar icon to reveal a gorgeously designed heads-up display that perfectly hugs the physical notch of modern MacBooks.
- ✨ **Premium Aesthetics** - Both the HUD and the Settings dialog feature meticulously crafted dark-mode themes, glassmorphism, and pixel-perfect SF Symbols alignment.
- 📊 **Real-time Quota Monitoring** - Displays your MiniMax API usage percentage directly in the menu bar (prioritizing the most critical quota).
- 📅 **Dual Quota Tracking** - Intuitively tracks both your 5-hour interval and weekly quota thresholds with elegant visual progress bars.
- 🔄 **Auto-Refresh & Alerts** - Automatically updates every 5 minutes and pushes a native macOS notification if your quota critically exceeds 90%.
- 🔐 **Secure by Default** - Your API key is encrypted and stored securely in the local macOS Keychain.

## Screenshot

![MiniMaxQuotaBar Screenshot](minimax-quota-bar.png)

## Installation

### From Release

1. Download the latest `.app` from [Releases](https://github.com/rubenvieira/minimax-quota-bar/releases)
2. Move to `/Applications/`
3. Run the app

### From Source

```bash
# Clone the repository
git clone https://github.com/rubenvieira/minimax-quota-bar.git
cd minimax-quota-bar

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project MiniMaxQuotaBar.xcodeproj -scheme MiniMaxQuotaBar -configuration Release build

# The app will be in ~/Library/Developer/Xcode/DerivedData/MiniMaxQuotaBar-*/Build/Products/Release/
```

## Setup

1. **Launch the app** - It will appear in your menu bar
2. **Configure your API key** - Click the menu bar item and go to Settings (⌘,) to enter your MiniMax API key
3. **(Optional) Add to Login Items**:
   - System Settings → General → Login Items
   - Add "MiniMaxQuotaBar"

## Usage

- Click the percentage in the menu bar to reveal the **Notch HUD**.
- The HUD masterfully wraps around your MacBook notch to display:
  - **5h Interval (Left)** - Current usage mapped with a clean, pill-shaped progress bar and time until reset.
  - **Weekly (Right)** - Symmetrical weekly usage metrics matching the left side.
  - **Action Center (Bottom Center)** - Refresh, Settings, and Quit controls perfectly nestled right below the physical camera notch.
- **Settings** - Configure your API key in the newly redesigned, beautiful dark-mode preference panel.

## Configuration

The API key is configured directly in the app via **Settings** (⌘,). Your key is stored securely in macOS Keychain.

## Status Icons

The menu bar shows the percentage based on whichever quota (5h or weekly) is more critical.

| Usage | Color | SF Symbol |
|-------|-------|-----------|
| 0-75% | Green | gauge.medium |
| 75-90% | Yellow | gauge.high |
| 90-100% | Red | gauge.with.needle |
| Error | Red | exclamationmark.triangle |

## Tech Stack

- **Swift 5.9** - Programming language
- **AppKit** - Native macOS UI framework
- **URLSession** - Network requests
- **Foundation** - Core utilities

## Project Structure

```
MiniMaxQuotaBar/
├── MiniMaxQuotaBarApp.swift   # Main app code
├── Assets.xcassets/            # App icons
├── project.yml                 # XcodeGen configuration
├── MiniMaxQuotaBar.xcodeproj/ # Generated Xcode project
├── README.md                   # This file
└── LICENSE                    # MIT License
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) first.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [MiniMax API](https://platform.minimaxi.com) - For providing the quota API
