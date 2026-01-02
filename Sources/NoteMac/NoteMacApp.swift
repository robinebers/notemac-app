import SwiftUI
import AppKit

// App version derived from Info.plist
let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

// MARK: - AppDelegate for proper macOS app activation

// Key for manual window frame persistence (setFrameAutosaveName is broken for multi-monitor)
private let windowFrameKey = "NoteMacMainWindowFrame"

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set activation policy BEFORE app finishes launching
        // This makes the app a "regular" foreground app with menu bar and Dock icon
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Manually restore window frame BEFORE making visible
        // Note: setFrameAutosaveName is broken for multi-monitor - always restores to primary display
        // So we use manual save/restore with NSStringFromRect/NSRectFromString
        if let window = NSApp.windows.first,
           let frameString = UserDefaults.standard.string(forKey: windowFrameKey),
           !frameString.isEmpty {
            let savedFrame = NSRectFromString(frameString)
            if savedFrame.width > 0 && savedFrame.height > 0 {
                // Validate frame is visible on at least one current screen
                // (handles case where external monitor was disconnected)
                let isVisible = NSScreen.screens.contains { screen in
                    screen.visibleFrame.intersects(savedFrame)
                }
                if isVisible {
                    window.setFrame(savedFrame, display: false)
                } else {
                    // Saved frame is off-screen (monitor disconnected), center instead
                    window.center()
                }
            }
        }

        // Now activate the app and bring it to the foreground
        NSApp.activate(ignoringOtherApps: true)

        // Make the main window key
        DispatchQueue.main.async {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Quit when all windows are closed
        return true
    }
}

@main
struct NoteMacApp: App {
    // Use AppDelegate for proper macOS app activation
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Try to restore from previous session
        if let sessionData = try? SessionStore.load() {
            _appState = State(initialValue: AppState.restore(from: sessionData))
        } else {
            _appState = State(initialValue: AppState())
        }
    }

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            MainWindow(appState: appState)
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // About menu
            CommandGroup(replacing: .appInfo) {
                Button("About NoteMac") {
                    openWindow(id: "about")
                }
            }
            FileCommands(appState: appState)
            EditCommands(appState: appState)
            ViewCommands(appState: appState)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Save session when app becomes inactive or goes to background
            if newPhase == .inactive || newPhase == .background {
                saveSession()
            }
        }

        Window("About NoteMac", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }

    /// Save the current session to persistent storage
    private func saveSession() {
        do {
            try SessionStore.save(appState: appState)
        } catch {
            print("Failed to save session: \(error)")
        }
    }
}

struct FileCommands: Commands {
    @Bindable var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                appState.newDocument()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open...") {
                appState.openFile()
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                appState.saveActiveDocument()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Save As...") {
                appState.saveActiveDocumentAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandGroup(after: .saveItem) {
            Button("Close Tab") {
                if let activeID = appState.activeDocumentID {
                    appState.closeDocument(id: activeID)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }
}

struct EditCommands: Commands {
    @Bindable var appState: AppState

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Find...") {
                appState.findBarVisible = true
                appState.showReplaceField = false
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Find and Replace...") {
                appState.findBarVisible = true
                appState.showReplaceField = true
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button("Find Next") {
                if !appState.findBarVisible {
                    appState.findBarVisible = true
                }
                appState.findNextAction?()
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(appState.searchText.isEmpty)

            Button("Find Previous") {
                if !appState.findBarVisible {
                    appState.findBarVisible = true
                }
                appState.findPreviousAction?()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(appState.searchText.isEmpty)
        }
    }
}

struct ViewCommands: Commands {
    @Bindable var appState: AppState

    private let minFontSize: CGFloat = 8
    private let maxFontSize: CGFloat = 72

    var body: some Commands {
        CommandGroup(replacing: .toolbar) {
            Toggle("Show Sidebar", isOn: $appState.sidebarVisible)
                .keyboardShortcut("b", modifiers: .command)

            Divider()

            Toggle("Word Wrap", isOn: $appState.wordWrapEnabled)
                .keyboardShortcut("w", modifiers: [.command, .option])

            Toggle("Show Line Numbers", isOn: $appState.showLineNumbers)

            Divider()

            Button("Increase Font Size") {
                appState.fontSize = min(appState.fontSize + 1, maxFontSize)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Decrease Font Size") {
                appState.fontSize = max(appState.fontSize - 1, minFontSize)
            }
            .keyboardShortcut("-", modifiers: .command)
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var linkColor: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.6, blue: 1.0) : Color(red: 0.0, green: 0.4, blue: 0.9)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("NoteMac")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version \(appVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Text("A simple, fast text editor for macOS")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text("Made with")
                Text("❤️")
                Text("by")
                Link("Robin Ebers", destination: URL(string: "https://itsbyrob.in/x")!)
                    .foregroundColor(linkColor)
                    .fontWeight(.bold)
            }
            .font(.caption)
        }
        .padding(32)
        .frame(width: 280)
    }
}
