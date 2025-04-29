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
        .navigationTitle("MultiPing Setup") // Set a window title
        .toolbar {
             // Keep the toolbar clean
             ToolbarItem(placement: .principal) {
                 EmptyView()
             }
         }
    }

    // --- Helper Functions (validateSettings, preparePing, isValidIPAddress, openResultsWindow) ---
    // (Keep the existing helper functions as they were in the previous version)

    // Validate timeout and interval (optional enhancement)
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

    // Prepare data and open the results window
    func preparePing() {
        // Validate settings before proceeding
        validateSettings()

        // Get a reference to the current window to close it later
        let inputWindow = NSApp.keyWindow

        // Clear previous results
        manager.results.removeAll()
        // Reset ping status before starting a new session
        pingStatus = "Preparing..." // Indicate preparation state
        manager.pingStarted = false // Ensure pingStarted is false initially

        // Parse IP addresses from the input text editor
        let ips = manager.ipInput
            .split { $0.isNewline || $0 == "," } // Split by newline or comma
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } // Remove extra spaces
            .filter { !$0.isEmpty && isValidIPAddress($0) } // Filter out empty strings and invalid IPs

        // Create PingResult for each valid IP with all required initial values.
        for ip in ips {
            manager.results.append(PingResult(
                ip: ip,
                responseTime: "Pending", // Initial status
                successCount: 0,       // Initialize count
                failureCount: 0,       // Initialize count
                failureRate: 0.0,      // Initialize rate
                isSuccessful: false    // Initial state
            ))
        }

        // Check if there are any valid IPs to ping
        if manager.results.isEmpty {
             print("No valid IP addresses entered.")
             pingStatus = "No valid IPs" // Update status
             // Optionally show an alert to the user here
             return // Don't open the results window if no IPs
        }


        // Open the results window
        openResultsWindow()

        // Close the input window after opening the results window
        inputWindow?.close()
    }

    // Function to validate IP address format (basic check)
     func isValidIPAddress(_ ipString: String) -> Bool {
         // Basic check for IPv4 format (four numbers 0-255 separated by dots)
         // This is a simplified check and might not cover all edge cases or IPv6.
         let parts = ipString.split(separator: ".")
         guard parts.count == 4 else { return false }
         return parts.allSatisfy { part in
             guard let number = Int(part) else { return false }
             return number >= 0 && number <= 255
         }
     }


    // Open the dedicated window for showing ping results
    func openResultsWindow() {
        // Create a new window if it doesn't exist
        if resultsWindow == nil {
            resultsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 600), // Adjusted size
                styleMask: [.titled, .closable, .resizable, .miniaturizable], // Added miniaturizable
                backing: .buffered,
                defer: false)
            resultsWindow?.center() // Center on screen
            resultsWindow?.setFrameAutosaveName("Ping Results Window") // Remember position/size
            resultsWindow?.title = "Ping Results" // Set window title
        }

        // Set the content view of the window to PingResultsView
        // Pass the necessary data and bindings
        resultsWindow?.contentView = NSHostingView(rootView: PingResultsView(
            manager: manager, // Pass the shared manager
            timeout: timeout, // Pass the current setting
            interval: interval, // Pass the current setting
            size: size, // Pass the current setting
            pingStatus: $pingStatus // Pass the binding for status updates
        ))

        // Bring the window to the front
        resultsWindow?.makeKeyAndOrderFront(nil)
    }
}

