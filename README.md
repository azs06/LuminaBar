# LuminaBar

A native macOS menu bar app to control Yeelight smart bulbs on your local network.

<img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
<img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift 5.9">

## Features

- **Menu bar control** - Quick access from your menu bar
- **Auto-discovery** - Finds Yeelight bulbs on your network automatically
- **Full controls** - Power, brightness, color temperature, RGB color picker
- **Native & lightweight** - Built with SwiftUI, minimal resource usage
- **Preset colors** - Quick access to common colors

## Installation

### Homebrew (Recommended)

```bash
brew tap azs06/tap
brew install --cask luminabar
```

### Manual Download

Download the latest `.dmg` from [Releases](https://github.com/azs06/LuminaBar/releases), open it, and drag LuminaBar to Applications.

### Build from Source

```bash
git clone https://github.com/azs06/LuminaBar.git
cd LuminaBar
./Scripts/build-app.sh
cp -r LuminaBar.app /Applications/
```

## Requirements

- macOS 14 (Sonoma) or later
- Yeelight bulb with **LAN Control** enabled

### Enabling LAN Control

1. Open the Yeelight app on your phone
2. Tap your bulb → Settings (gear icon)
3. Enable "LAN Control"

This only needs to be done once per bulb.

## Usage

1. Launch LuminaBar - a lightbulb icon appears in your menu bar
2. Click the icon to open the control panel
3. Your Yeelight bulbs will be discovered automatically
4. Use the controls to adjust power, brightness, color temperature, or RGB color

## Troubleshooting

**No devices found?**
- Ensure your Mac and Yeelight are on the same WiFi network
- Verify LAN Control is enabled in the Yeelight app
- Click the refresh button to scan again

**"App can't be opened" warning?**
- Right-click the app → Open (first time only)
- Or: System Settings → Privacy & Security → Open Anyway

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please open an issue or submit a pull request.
