# Fluent VLC Player

<div align="center">
  <img src="assets/images/logo.png" alt="Fluent VLC Player Logo" width="120" height="120">
  
  <h3>A Modern Video Player with Material You Design</h3>
  
  <p>
    <img src="https://img.shields.io/badge/Flutter-3.0+-blue.svg" alt="Flutter">
    <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg" alt="Platform">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
  </p>
</div>

## ✨ Features

### 🎨 Material You Design
- Dynamic color extraction from wallpaper
- Fluent Design System inspired UI
- Customizable accent colors
- Light/Dark/AMOLED theme support

### 🎬 Advanced Video Playback
- Based on VLC media player
- Hardware acceleration support
- Multiple video format support
- Network stream playback

### 🔄 Seamless Loop Playback
- Zero-gap loop playback technology
- No black screen between loops
- Perfect for background videos and music videos

### 🔒 Private Vault
- AES-256 encryption for sensitive files
- Password protection
- Biometric authentication support
- Auto-lock feature

### ⚙️ Local Settings
- Remember playback position
- Custom playback speed
- Hardware acceleration toggle
- Display preferences

## 📱 Screenshots

| Home Screen | Player | Vault | Settings |
|-------------|--------|-------|----------|
| ![Home](screenshots/home.png) | ![Player](screenshots/player.png) | ![Vault](screenshots/vault.png) | ![Settings](screenshots/settings.png) |

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.0 or higher
- Android Studio / Xcode
- Android SDK (for Android)
- CocoaPods (for iOS)

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/fluent_vlc_player.git
cd fluent_vlc_player
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

### Building for Release

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## 📋 Supported Formats

### Video
MP4, AVI, MKV, MOV, WebM, FLV, WMV, TS, M3U8, and more...

### Audio
MP3, AAC, FLAC, WAV, OGG, M4A, and more...

## 🔧 Configuration

### Android
Make sure to add these permissions in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### iOS
Add these to `Info.plist`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access</string>
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [VLC](https://www.videolan.org/vlc/) - The best open-source media player
- [Flutter VLC Player](https://github.com/solid-software/flutter_vlc_player) - Flutter VLC bindings
- [Material Design 3](https://m3.material.io/) - Design guidelines
- [Fluent UI System Icons](https://aka.ms/fluentui-system-icons) - Beautiful icons

---

<div align="center">
  Made with ❤️ by Fluent VLC Player Team
</div>
