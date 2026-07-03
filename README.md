# ClipBoard

A lightweight macOS clipboard manager with pin-to-screen support and customizable shortcuts.

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-brightgreen">
  <img src="https://img.shields.io/badge/Swift-6.0-orange">
  <img src="https://img.shields.io/badge/License-MIT-blue">
</p>

---

## Features

- 📋 Clipboard history (text & images, up to 50 items)
- 🖼️ Pin images to screen (Snipaste-like floating windows)
- ⌨️ Global hotkeys for panel toggle, paste, and pin
- 🔧 Customizable keyboard shortcuts with live recording
- 🖱️ Scroll wheel & pinch-to-zoom on pinned images
- 🎯 Focus-aware zoom (only zooms the active pinned window)
- ⚡ Auto-launch at login
- 🔒 Menu bar only, no Dock icon (LSUIElement)

---

## Installation

### Option 1: Download pre-built app

Download the latest `ClipBoard.app` from [Releases](https://github.com/paidaxin01X/ClipBoard/releases).

### Option 2: Build from source

```bash
git clone https://github.com/paidaxin01X/ClipBoard.git
cd ClipBoard

cd ClipBoard
swift build -c release --product ClipBoard
bash ../Scripts/build-app.sh
open ../ClipBoard.app
```

> **Note**: macOS 14+ and Xcode Command Line Tools required.

---

## Usage

### Menu Bar

- **Left click** the menu bar icon → show clipboard history panel
- **Right click** → context menu (auto-launch toggle, preferences, quit)

### Default Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧V` | Toggle clipboard panel |
| `⌥1` ~ `⌥9` | Paste item 1~9 |
| `⌘⇧P` | Pin latest image to screen |
| `⌘=` | Zoom in pinned image |
| `⌘-` | Zoom out pinned image |
| `⌘R` | Reset zoom on pinned image |
| `↑` `↓` | Navigate history |
| `⏎` | Paste selected item |
| `⎋` | Close panel or close pinned image |

> All shortcuts except paste (⌥1~9) and navigation can be customized via **Preferences**.

### Pin to Screen

1. Copy an image to clipboard
2. Press `⌘⇧P` (or click the pin button in the panel) — the image appears as a floating window
3. **Zoom**: `⌘=` / `⌘-` / scroll wheel / trackpad pinch
4. **Reset zoom**: `⌘R`
5. **Move**: drag the window
6. **Close**: press `⎋`

When multiple images are pinned, zoom operations only affect the window under the mouse cursor (focus-aware).

---

## Customize Shortcuts

Right-click the menu bar icon → **Preferences...** → click a shortcut row → press your desired key combination.

- Must include at least one modifier key (⌘/⌥/⇧/⌃)
- Changes take effect immediately and persist across restarts
- Click **Reset to Defaults** to restore factory settings

---

## Project Structure

```
ClipBoard/
├── ClipBoard/                  # Swift Package
│   ├── Package.swift
│   └── Sources/
│       ├── ClipBoardCore/      # Core library
│       │   ├── ClipboardItem.swift      # Data model
│       │   ├── ClipboardManager.swift   # Clipboard monitoring + persistence
│       │   ├── HotkeyManager.swift      # Carbon global hotkeys
│       │   └── KeyBinding.swift         # Key binding model + store
│       └── ClipBoard/          # Main app
│           ├── main.swift               # PinApplication (NSApplication subclass)
│           ├── AppDelegate.swift         # Status bar, popover, menu
│           ├── PinManager.swift          # Pin management + focus tracking
│           ├── PinWindow.swift           # Pin window + content view
│           ├── ShortcutSettingsView.swift # Preferences UI
│           ├── ClipboardListView.swift   # History panel
│           ├── ClipboardItemRow.swift    # History row
│           ├── ClipBoardApp.swift        # SwiftUI entry
│           └── Info.plist                # LSUIElement = YES
├── Scripts/
│   ├── build-app.sh
│   └── install.sh
├── Resources/
│   └── AppIcon.icns
├── README.md
└── README.zh.md
```

---

## Technical Notes

- **LSUIElement = YES**: The app runs as a menu bar agent without a Dock icon. This means `magnify` (pinch-to-zoom) events must be intercepted via `PinApplication.sendEvent` override rather than the standard responder chain.
- **Carbon Hotkeys**: `RegisterEventHotKey` is used for global hotkeys (signature `CLIB`). Zoom shortcuts were migrated from Carbon to `sendEvent` for reliability.
- **Swift 6 Concurrency**: All manager classes are annotated with `@MainActor`. Key model types conform to `Sendable`.
- **NSPasteboard Polling**: Clipboard is checked every 500ms via `Timer` + `changeCount`.
- **No XCTest**: Manual test runner using `assert()`.

---

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you'd like to change.

Feature requests and bug reports are always welcome — feel free to [open an issue](https://github.com/paidaxin01X/ClipBoard/issues).

---

## License

MIT License.
