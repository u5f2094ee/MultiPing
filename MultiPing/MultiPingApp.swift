import SwiftUI

@main
struct MultiPingApp: App {
    @StateObject private var manager = PingManager()

    @State private var timeout: String = "2000" // Timeout in ms
    @State private var interval: String = "10"   // Interval in seconds (default to 5)
    @State private var size: String = "32"      // Ping size in bytes
    @State private var pingStatus: String = "Stopped"  // Initial ping status

    var body: some Scene {
        WindowGroup {
            IPInputView(manager: manager, timeout: $timeout, interval: $interval, size: $size)
                .onChange(of: manager.pingStarted) { _ in
                    updatePingStatus()  // Update status when the ping starts or stops
                }
        }
    }

    func updatePingStatus() {
        if manager.pingStarted {
            pingStatus = "Pinging in progress"
        } else {
            pingStatus = "Paused"
        }
    }
}
