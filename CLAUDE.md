# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build release and create app bundle
./Scripts/build-app.sh

# Build only (without app bundle)
swift build -c release

# Create DMG for distribution
hdiutil create -volname LuminaBar -srcfolder LuminaBar.app -ov -format UDZO LuminaBar.dmg

# Install locally
cp -r LuminaBar.app /Applications/
```

## Architecture

LuminaBar is a native macOS menu bar app for controlling Yeelight smart bulbs over LAN. Built with Swift 5.9 and SwiftUI, targeting macOS 14+.

### Core Components

**App Entry & Menu Bar (`LuminaBarApp.swift`)**
- `LuminaBarApp`: SwiftUI App with empty Settings scene (menu bar only)
- `AppDelegate`: Manages NSStatusItem (menu bar icon) and NSPopover. Handles color panel observation to switch popover behavior between transient/semitransient when system color picker is open

**Device Discovery (`Yeelight/YeelightManager.swift`)**
- Singleton `YeelightManager.shared` using `@Observable` macro
- SSDP multicast discovery on `239.255.255.250:1982`
- Uses `NWConnectionGroup` for UDP multicast, parses Yeelight discovery responses
- 3-second discovery timeout

**Device Control (`Yeelight/YeelightDevice.swift`)**
- `YeelightDevice`: Represents a single bulb with TCP connection management
- JSON-RPC command protocol over TCP with 5-second command timeout
- Supports: power, brightness (1-100), color temperature (1700-6500K), RGB
- `colorMode`: 1 = RGB mode, 2 = color temperature mode
- Async command API with `CheckedContinuation` for response handling

**UI (`PopoverView.swift`, `DeviceCardView.swift`)**
- `PopoverView`: Main popover showing device list or empty state
- `DeviceCardView`: Per-device controls with local state for smooth slider interaction (syncs back to device on release)
- `ColorWellView`: NSColorWell wrapper for system color picker integration

### Key Patterns

- All UI state uses `@Observable` macro (not ObservableObject)
- `@MainActor` isolation on all UI-related classes
- `nonisolated` functions for thread-safe network callbacks
- Slider controls use local state to avoid laggy updates during dragging
