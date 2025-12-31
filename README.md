# NoteMac

A simple, fast text editor for macOS built with SwiftUI with basic Markdown support. Purely a vibe coded experiment for testing purposes — not a single line of code was written or read in the process. Built in a few hours.

![NoteMac Screenshot](notemac.png)

## Releases

Download a ready-to-use version in the [release section](https://github.com/robinebers/notemac-app/releases).

## Features

**Editor**
- Native macOS app with SwiftUI + [STTextView](https://github.com/krzyzanowskim/STTextView)
- Tabbed document interface with drag-to-reorder
- Bear-style live Markdown rendering (syntax visible but dimmed at 40% opacity)
- Find and replace with wrap-around navigation
- Adjustable font size (⌘+/⌘-)
- Toggle word wrap and line numbers

**File Handling**
- Supports `.txt`, `.md`, and `.markdown` files
- Automatic encoding detection (UTF-8, UTF-16, ASCII, ISO Latin 1)
- Preserves line endings (LF/CRLF)

**Session Persistence**
- Reopens all documents on launch with cursor positions restored
- Remembers window position (multi-monitor aware)
- Document recovery if files are moved/deleted

## Requirements

- macOS 15.0 (Sequoia)+
- Xcode 16+ / Swift 6.0+

## Development

```bash
# Run the app
swift run

# Run tests
swift test
```

## Building for Distribution

The app uses Apple's notarization for distribution outside the App Store.

### Prerequisites

1. **Apple Developer ID certificate** - Get from [Apple Developer Portal](https://developer.apple.com/account/resources/certificates)
2. **notarytool credentials** - Store in Keychain:
   ```bash
   xcrun notarytool store-credentials "notarytool-profile" \
       --apple-id "your@email.com" \
       --team-id "YOUR_TEAM_ID"
   ```

### Setup

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

Required variables:
| Variable | Description |
|----------|-------------|
| `SIGNING_IDENTITY` | Your Developer ID certificate name (from `security find-identity -v -p codesigning`) |
| `KEYCHAIN_PROFILE` | The profile name used with `notarytool store-credentials` |

### Build & Notarize

```bash
# Full build, sign, and notarize
./scripts/build-and-notarize.sh

# Build and sign only (for local testing)
./scripts/build-and-notarize.sh --skip-notarize
```

Output:
- `build/NoteMac.app` - Signed and notarized app bundle
- `build/NoteMac.zip` - Ready for distribution

## Project Structure

```
notemac-app/
├── Sources/NoteMac/
│   ├── NoteMacApp.swift          # App entry, AppDelegate, menu commands
│   ├── Models/
│   │   ├── AppState.swift        # Central state, document lifecycle
│   │   └── Document.swift        # Document model, modification tracking
│   ├── Views/
│   │   ├── MainWindow.swift      # Window layout, find operations
│   │   ├── EditorView.swift      # Text editor with markdown plugin
│   │   ├── Sidebar.swift         # Document list with drag reorder
│   │   ├── FindBar.swift         # Search/replace UI
│   │   └── StatusBar.swift       # Cursor position, encoding, line endings
│   └── Services/
│       ├── FileService.swift     # File I/O, encoding detection
│       ├── SessionStore.swift    # Session persistence (JSON)
│       └── MarkdownStyler.swift  # Markdown AST parsing + styling
├── Tests/NoteMacTests/
├── Resources/
│   ├── AppIcon.icns              # App icon
│   └── Assets.car                # Compiled assets (Tahoe Liquid Glass)
├── Design/AppIcon/               # Source icon files and exports
├── scripts/
│   └── build-and-notarize.sh
├── Info.plist                    # App bundle metadata
├── NoteMac.entitlements          # Hardened runtime permissions
└── Package.swift
```

## License

MIT
