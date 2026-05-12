# SafeBrowser - Secure iOS Mobile Browser

<p align="center">
  <img src="https://img.shields.io/badge/iOS-15.0%2B-blue" alt="iOS Version">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift Version">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

> 🚀 High-performance iOS mobile browser based on WebKit with video playback, reading mode, and download management

## ✨ Features

### 🧭 Basic Browsing

- **Smart Address Bar** - Auto-detect URLs and search queries
- **Navigation Controls** - Forward, backward, refresh
- **Progress Display** - Real-time page loading progress
- **Gesture Support** - Swipe gestures for navigation
- **Share Function** - One-click page sharing

### 🎬 Video Playback

- **Auto Detection** - Smart page video recognition
- **Multiple Playback Modes**
  - Fullscreen playback
  - Picture-in-Picture mode
  - Inline playback
- **Controls**
  - Play/Pause
  - Progress bar
  - Volume control
- **AirPlay Support** - Cast to external devices

### 📥 Download Management

- **Video Downloads** - One-click page video download
- **Audio Downloads** - Audio file support
- **Download Manager**
  - Real-time progress display
  - File size display
  - Download list management
- **File Operations**
  - Share downloaded files
  - View in Files app

### 📖 Reading Mode

- **Smart Article Detection** - Auto-recognize news articles and blogs
- **Rich Media Support**
  - Article image display
  - Embedded video playback
- **Customization**
  - Font size adjustment (A-/A+)
  - Three theme modes
    - 💡 Light
    - 📜 Sepia
    - 🌙 Dark
  - Settings auto-save
- **Reading Experience**
  - Optimal reading width
  - Estimated read time
  - Chapter title recognition

### 🔒 Security Features

- **URL Validation** - Automatic download link verification
- **Safe Browsing** - Block malicious websites
- **Privacy Protection** - No user tracking
- **Content Security** - WebKit security policies

### 📱 Native iOS Experience

- **Responsive Design** - Adapts to all iOS devices
- **Dark Mode** - System dark mode support
- **Gestures** - Native iOS gesture support
- **Accessibility** - Complete VoiceOver support

## 🛠 Tech Stack

### Core Frameworks

- **UIKit** - User interface
- **WebKit** - Browser engine
- **AVKit** - Video playback
- **Foundation** - Base framework

### Build Tools

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - Project generation tool

### Architecture

```
SafeBrowser/
├── Sources/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   └── SceneDelegate.swift
│   ├── Browser/
│   │   ├── BrowserViewController.swift    # Main browser controller
│   │   ├── VideoDownloadManager.swift     # Video download manager
│   │   └── ReadingModeManager.swift       # Reading mode manager
│   └── Utils/
│       └── (Extensions)
└── Resources/
    ├── Info.plist
    ├── en.lproj/Localizable.strings       # English strings
    └── zh-Hans.lproj/Localizable.strings # Chinese strings
```

## 🚀 Getting Started

### Requirements

- Xcode 15.0+
- iOS 15.0+ deployment target
- Swift 5.9+
- macOS 13+ (Ventura)

### Installation

1. **Clone the project**
   ```bash
   git clone https://github.com/yourusername/safechrome.git
   cd safechrome
   ```
2. **Install XcodeGen**
   ```bash
   # Using Homebrew
   brew install xcodegen

   # Or using Mint
   mint install yonaskolb/xcodegen
   ```
3. **Generate Xcode project**
   ```bash
   cd ios
   xcodegen generate
   ```
4. **Open project**
   ```bash
   open SafeBrowser.xcodeproj
   ```
5. **Run project**
   - Select target device/simulator in Xcode
   - Press `⌘+R` or click Run button

### Build

#### Debug Build

```bash
cd ios
xcodebuild -project SafeBrowser.xcodeproj \
  -scheme SafeBrowser \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

#### Release Build

```bash
xcodebuild -project SafeBrowser.xcodeproj \
  -scheme SafeBrowser \
  -configuration Release \
  CODE_SIGN_IDENTITY="Your Code Sign Identity" \
  CODE_SIGNING_REQUIRED=YES \
  build
```

## 📱 Usage Guide

### Basic Browsing

1. Enter URL or search query in address bar
2. Press return to load
3. Use bottom toolbar for navigation

### Video Playback

1. Open webpage with video (e.g., YouTube)
2. Video button appears in bottom toolbar
3. Tap to choose playback mode

### Download Videos

1. Play video and tap download button
2. Select "Download Page Video"
3. Wait for download to complete
4. Use share or Files app to view

### Reading Mode

1. Open news article or blog
2. Tap 📄 button in toolbar
3. Enjoy clean reading experience
4. Adjust settings with bottom toolbar
5. Tap ❌ or 📄 again to exit

## 🎯 Project Structure

```
ios/
├── project.yml                 # XcodeGen configuration
├── SafeBrowser.xcodeproj/     # Xcode project
├── SafeBrowser/
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── AppDelegate.swift      # App lifecycle
│   │   │   └── SceneDelegate.swift    # Scene management
│   │   ├── Browser/
│   │   │   ├── BrowserViewController.swift  # Main controller
│   │   │   ├── VideoDownloadManager.swift   # Download manager
│   │   │   └── ReadingModeManager.swift     # Reading mode
│   │   └── (Other modules)
│   └── Resources/
│       ├── Info.plist
│       ├── LaunchScreen.storyboard
│       ├── en.lproj/Localizable.strings     # English
│       └── zh-Hans.lproj/Localizable.strings # Chinese
└── SafeBrowser.xcworkspace/   # Workspace
```

## 🔧 Configuration

### Info.plist Configuration

```xml
<!-- Network Security -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
    <key>NSAllowsArbitraryLoadsForMedia</key>
    <true/>
</dict>

<!-- Background Downloads -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

### Project Configuration (project.yml)

```yaml
name: SafeBrowser
options:
  deploymentTarget:
    iOS: "15.0"
  xcodeVersion: "15.0"

targets:
  SafeBrowser:
    type: application
    platform: iOS
    deploymentTarget: "15.0"
```

## 🌍 Internationalization

SafeBrowser supports multiple languages:

- 🇺🇸 English (en)
- 🇨🇳 Simplified Chinese (zh-Hans)

### Adding New Languages

1. Create new localization folder: `Resources/xx.lproj/`
2. Copy and translate `Localizable.strings`
3. Update `project.yml` to include new localization
4. Run `xcodegen generate`

## 🐛 FAQ

### Q: Why WKWebView instead of UIWebView?

**A:** WKWebView is Apple's recommended modern browser engine with better performance, lower memory usage, and more features.

### Q: Why can't iOS use Chromium engine?

**A:** Apple's App Store policy requires all browsers to use WebKit engine. This is a system restriction, not a technical limitation.

### Q: How to handle blocked video downloads?

**A:** Some sites use DRM protection - these videos cannot be downloaded. This is normal copyright protection.

### Q: Reading mode can't recognize some articles?

**A:** Some sites use complex JavaScript rendering. Try refreshing the page and retry.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Create Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## 🙏 Acknowledgments

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - Project generation tool
- [Apple Developer Documentation](https://developer.apple.com/documentation/) - Technical documentation
- All open source community contributors

<br />

***

<p align="center">
  🚀 Enjoy safe, fast mobile browsing with SafeBrowser
</p>
