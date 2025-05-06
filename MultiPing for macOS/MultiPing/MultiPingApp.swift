import SwiftUI

@main
struct MultiPingApp: App {
    // Manager object shared across views
    @StateObject private var manager = PingManager()

    var body: some Scene {
        // Use Window instead of WindowGroup for styling
        Window("IP Collector", id: "ip-input") { // Title is set here
            // Initialize IPInputView with manager
            IPInputView(manager: manager)
        }
        // Apply window style modifiers
        // REMOVED: .windowStyle(.hiddenTitleBar) // This was hiding the title text
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)   // Integrates toolbar area with title bar space, allowing title to show
        // Optional: Set default size if needed (IPInputView already has .frame)
        // .defaultSize(width: 500, height: 380)
    }
}

