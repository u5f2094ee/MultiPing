import SwiftUI
import AppKit // Import AppKit for NSWindow and NSApp

struct IPInputView: View {
    // Use @StateObject if the view creates the manager, @ObservedObject if passed in
    @ObservedObject var manager: PingManager
    // Bindings for settings managed by the parent view (MultiPingApp)
    @Binding var timeout: String
    @Binding var interval: String
    @Binding var size: String

    // State for managing the results window
    @State private var resultsWindow: NSWindow?
    // State for the ping status, passed as a binding to PingResultsView
    @State private var pingStatus: String = "Stopped"

    // --- Body remains the same as the version with the Okay button moved up ---
    var body: some View {
        // Use a VStack to arrange elements vertically
        VStack(spacing: 15) { // Add some spacing between elements

            // --- Top Row: Settings Fields and Okay Button ---
            HStack(alignment: .bottom, spacing: 15) { // Align items to the bottom, add spacing
                // Timeout Field
                VStack(alignment: .leading) {
                    Text("Timeout (ms)")
                        .font(.caption)
                    TextField("1000", text: $timeout)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
                // Interval Field
                VStack(alignment: .leading) {
                    Text("Interval (s)")
                        .font(.caption)
                    TextField("5", text: $interval)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
                // Size Field
                VStack(alignment: .leading) {
                    Text("Size (bytes)")
                        .font(.caption)
                    TextField("56", text: $size)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }

                Spacer() // Push the button to the right if needed, or remove for center alignment

                // --- Okay Button (Moved Here) ---
                Button("Okay") { // Changed label to "Okay"
                    preparePing()
                }
                .buttonStyle(.borderedProminent)
                // Disable button if no IPs are entered
                .disabled(manager.ipInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                // Add slight padding to align baseline with text fields if needed
                // .padding(.bottom, 5)
            }
            .padding(.top) // Add padding above the top row
            .padding(.horizontal) // Add horizontal padding to the row

            // --- IP Address Input Area Label ---
            Text("Enter IP Addresses (one per line or comma-separated)")
                 .font(.caption)
                 .frame(maxWidth: .infinity, alignment: .leading) // Align text left
                 .padding(.horizontal) // Match horizontal padding

            // --- IP Address Input TextEditor (Takes Max Height) ---
            ZStack(alignment: .topLeading) {
                // Use TextEditor for multi-line input
                TextEditor(text: $manager.ipInput)
                    // Allow the TextEditor to expand vertically
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.gray.opacity(0.5), width: 1) // Add a border

                // Placeholder text
                if manager.ipInput.isEmpty {
                    Text("e.g., 8.8.8.8\n1.1.1.1, 192.168.1.1")
                        .foregroundColor(.secondary)
                        .padding(.leading, 5) // Indent placeholder slightly
                        .padding(.top, 8)
                        .allowsHitTesting(false) // Make placeholder non-interactive
                }
            }
            // Remove fixed height constraints to allow expansion
            // .frame(minHeight: 100, maxHeight: 200) // Removed fixed height
            .padding(.horizontal) // Add horizontal padding
            .layoutPriority(1) // Give the TextEditor higher priority to expand

        }
        .padding(.vertical) // Add padding around the main VStack content
        // Set a minimum size, but allow it to grow
        .frame(minWidth: 450, minHeight: 350) // Adjusted min width slightly
        // Remove the explicit navigation title from the view itself
        // .navigationTitle("MultiPing Setup")
        .toolbar {
             // Keep the toolbar clean
             ToolbarItem(placement: .principal) {
                 EmptyView()
             }
         }
    }

    // --- Helper Functions (validateSettings, preparePing, isValidIPAddress) ---
    // (Keep these functions as they were)
    func validateSettings() {
        // Ensure values are numeric and reasonable
        if Int(timeout) == nil { timeout = "1000" } // Default if invalid
        if Int(interval) == nil || (Int(interval) ?? 1) < 1 { interval = "5" } // Default/minimum if invalid
        if Int(size) == nil { size = "56" } // Default if invalid

        // Example validation: Timeout shouldn't drastically exceed interval
        if let timeoutValue = Int(timeout), let intervalValue = Int(interval) {
             // Allow timeout up to interval * 1000 ms
            if timeoutValue > intervalValue * 1000 {
                 // Adjust timeout to be equal to interval in ms as a fallback
                 timeout = String(intervalValue * 1000)
                 print("Warning: Timeout adjusted to match interval duration.")
             }
        }
    }
    func preparePing() {
        validateSettings()
        let inputWindow = NSApp.keyWindow
        manager.results.removeAll()
        pingStatus = "Preparing..."
        manager.pingStarted = false

        let ips = manager.ipInput
            .split { $0.isNewline || $0 == "," }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && isValidIPAddress($0) }

        for ip in ips {
            manager.results.append(PingResult(
                ip: ip,
                responseTime: "Pending",
                successCount: 0,
                failureCount: 0,
                failureRate: 0.0,
                isSuccessful: false
            ))
        }

        if manager.results.isEmpty {
             print("No valid IP addresses entered.")
             pingStatus = "No valid IPs"
             return
        }
        openResultsWindow()
        inputWindow?.close()
    }
     func isValidIPAddress(_ ipString: String) -> Bool {
         let parts = ipString.split(separator: ".")
         guard parts.count == 4 else { return false }
         return parts.allSatisfy { part in
             guard let number = Int(part) else { return false }
             return number >= 0 && number <= 255
         }
     }


    // --- openResultsWindow (Modified) ---
    func openResultsWindow() {
        // Create a new window if it doesn't exist
        if resultsWindow == nil {
            resultsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 450), // Adjusted default size
                // Use .unifiedTitleAndToolbar or similar for better toolbar integration
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .unifiedTitleAndToolbar],
                backing: .buffered,
                defer: false)
            resultsWindow?.center()
            resultsWindow?.setFrameAutosaveName("Ping Results Window")
            // --- FIX APPLIED HERE: Remove explicit title setting ---
            // resultsWindow?.title = "Ping Results" // Removed this line
            // --- END OF FIX ---

            // Optional: Make title bar transparent for better toolbar look
            resultsWindow?.titlebarAppearsTransparent = true
        }

        // Set the content view of the window to PingResultsView
        resultsWindow?.contentView = NSHostingView(rootView: PingResultsView(
            manager: manager,
            timeout: timeout,
            interval: interval,
            size: size,
            pingStatus: $pingStatus
        ))

        resultsWindow?.makeKeyAndOrderFront(nil)
    }
}

