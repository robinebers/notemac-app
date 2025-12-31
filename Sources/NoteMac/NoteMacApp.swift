import SwiftUI

@main
struct NoteMacApp: App {
    var body: some Scene {
        WindowGroup {
            Text("NoteMac")
                .frame(width: 600, height: 400)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
