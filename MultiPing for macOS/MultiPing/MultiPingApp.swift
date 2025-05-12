import SwiftUI

@main
struct MultiPingApp: App {
    // Manager object shared across views
    @StateObject private var manager = PingManager()

    var body: some Scene {
        // Use Window instead of WindowGroup for styling
        // Window title changed from "IP Collector" to "Targets Collector"
        Window("Targets Collector", id: "ip-input") { // Title updated here
            // Initialize IPInputView with manager
            IPInputView(manager: manager)
        }
        // Apply window style modifiers (Unchanged from v1.1)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        // Optional: Set default size if needed (IPInputView already has .frame)
        // .defaultSize(width: 500, height: 380)
    }
}
