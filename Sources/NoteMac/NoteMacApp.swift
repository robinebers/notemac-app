import SwiftUI
import AppKit

// MARK: - AppDelegate for proper macOS app activation

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set activation policy BEFORE app finishes launching
        // This makes the app a "regular" foreground app with menu bar and Dock icon
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate the app and bring it to the foreground
        NSApp.activate(ignoringOtherApps: true)

        // Make the main window key and bring to front
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
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

    var body: some Scene {
        WindowGroup {
            MainWindow(appState: appState)
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
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
            .disabled(appState.documents.count <= 1)
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
