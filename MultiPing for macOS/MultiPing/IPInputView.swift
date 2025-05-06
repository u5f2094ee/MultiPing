import SwiftUI
import AppKit
import Foundation // Needed for ceil()

// Enum for View Modes
enum ResultsViewMode: String, CaseIterable, Identifiable {
    case list = "≡ List Layout"
    case grid = "# Grid Layout"
    var id: String { self.rawValue }
}

struct IPInputView: View {
    @ObservedObject var manager: PingManager
    // Settings state is local to this view
    @State var timeout: String = "2000" // Default Timeout
    @State var interval: String = "10"  // Default Interval (will be updated dynamically)
    @State var size: String = "32"   // Default Size

    // Default to Grid View
    @State private var selectedViewMode: ResultsViewMode = .grid

    // Computed property to count valid IPs
    var validIPCount: Int {
        return countValidIPs(from: manager.ipInput)
    }

    // Computed property for suggested interval
    var suggestedInterval: Int {
        guard validIPCount > 0 else { return 1 } // Return 1 if count is 0

        // --- MODIFIED: Round up the division result ---
        // Perform division using floating-point numbers
        let rawSuggestion = Double(validIPCount) / 10.0
        // Round up to the nearest whole number using ceil()
        let roundedUpSuggestion = ceil(rawSuggestion)
        // Ensure the result is at least 1
        return max(1, Int(roundedUpSuggestion))
        // --- END MODIFIED ---
    }

    var body: some View {
        VStack(spacing: 15) {
            // Settings Row
            HStack(alignment: .bottom, spacing: 15) {
                VStack(alignment: .leading) { Text("Timeout (ms)").font(.caption); TextField("2000", text: $timeout).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80) }
                VStack(alignment: .leading) { Text("Interval (s)").font(.caption); TextField("", text: $interval).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80) }
                VStack(alignment: .leading) { Text("Size (bytes)").font(.caption); TextField("32", text: $size).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80) }
                Spacer()
            }.padding(.top).padding(.horizontal)

            // Interval Notice Text
            Text("Notice:\nTo avoid inaccurate results when pinging many IPs,Please set the interval (seconds) to at least one-tenth of the total IP count \n(e.g., 10s for 100 IPs, 20s for 200 IPs).")
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true) // Allow vertical growth
                .padding(.horizontal)
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)


            // IP Input Area Label
            Text("Enter IP Addresses (one per line or comma-separated)").font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
            // Text Editor for IP Input
            ZStack(alignment: .topLeading) {
                TextEditor(text: $manager.ipInput).frame(maxWidth: .infinity, maxHeight: .infinity).border(Color.gray.opacity(0.5), width: 1)
                if manager.ipInput.isEmpty { Text("e.g., 8.8.8.8\n1.1.1.1, 192.168.1.1").foregroundColor(.secondary).padding(.leading, 5).padding(.top, 8).allowsHitTesting(false) }
            }.padding(.horizontal).layoutPriority(1)


            // Bottom Row (Controls)
            HStack {
                // Display Valid IP Count only
                Text("Count of Valid IPs: \(validIPCount)")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 20) // Add spacing after the count

                Text("Result layout:")
                    .font(.callout)
                    .padding(.trailing, 10)

                Picker("", selection: $selectedViewMode) {
                    ForEach(ResultsViewMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Spacer() // Pushes Okay button right

                Button("Start ping") { prepareAndStartPing() }
                    .buttonStyle(.borderedProminent)
                    // Disable Okay button if no valid IPs are entered
                    .disabled(validIPCount == 0)
            }
            .padding(.horizontal)
            .padding(.bottom)

        }
        .padding(.top)
        .frame(minWidth: 500, minHeight: 380)
        // --- MODIFIED TOOLBAR ---
        .toolbar {
            // Place the title text in the navigation (leading/left) area of the toolbar
            ToolbarItem(placement: .navigation) { // Changed from .principal to .navigation
                Text("IP Collector")
                    .font(.headline) // Optional: Style the text
                    .padding(.leading, 5) // Optional: Add some padding if needed
            }
        }
        // --- END MODIFIED TOOLBAR ---
        .onChange(of: validIPCount) { newCount in
            // Update the interval state variable whenever the valid IP count changes
            interval = String(suggestedInterval)
        }
        .onAppear {
             // Set the initial interval based on potentially pre-loaded IPs
             interval = String(suggestedInterval)
        }
    }

    // --- Helper Functions (Unchanged) ---
    func validateSettings() {
        if Int(timeout) == nil { timeout = "2000" }
        if Int(interval) == nil || (Int(interval) ?? 1) < 1 { interval = "1" } // Default to 1 if invalid
        if Int(size) == nil { size = "32" }
        if let timeoutValue = Int(timeout), let intervalValue = Int(interval) {
            if timeoutValue > intervalValue * 1000 {
                 timeout = String(intervalValue * 1000);
             }
        }
    }

    /// Parses an input string and returns an array of valid IP address strings.
    private func parseAndValidateIPs(from input: String) -> [String] {
        return input.split { $0.isNewline || $0 == "," }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && isValidIPAddress($0) }
    }

    /// Counts the number of valid IP addresses in an input string.
    private func countValidIPs(from input: String) -> Int {
        return parseAndValidateIPs(from: input).count
    }

    /// Checks if a single string is a valid IPv4 address.
    private func isValidIPAddress(_ ipString: String) -> Bool {
         let parts = ipString.split(separator: ".")
         guard parts.count == 4 else { return false }
         return parts.allSatisfy { part in guard let n = Int(part) else { return false }; return n >= 0 && n <= 255 }
     }

    func prepareAndStartPing() {
        validateSettings()
        let inputWindow = NSApp.keyWindow
        manager.results.removeAll()
        manager.pingStarted = false
        let ips = parseAndValidateIPs(from: manager.ipInput)
        guard !ips.isEmpty else { return }
        for ip in ips { manager.results.append(PingResult(ip: ip, responseTime: "Pending", successCount: 0, failureCount: 0, failureRate: 0.0, isSuccessful: false)) }
        manager.startPingTasks(timeout: self.timeout, interval: self.interval, size: self.size)
        openResultsWindow(mode: selectedViewMode)
        inputWindow?.close()
    }

    // --- UNCHANGED: openResultsWindow still sets the window title for the *new* windows ---
    func openResultsWindow(mode: ResultsViewMode) {
        let rootView: AnyView
        let windowTitle: String // This title is for the *results* window, not the input window
        switch mode {
        case .list: rootView = AnyView(PingResultsView(manager: manager, timeout: timeout, interval: interval, size: size)); windowTitle = "Ping Results (List)"
        case .grid: rootView = AnyView(GridPingResultsView(manager: manager, timeout: timeout, interval: interval, size: size)); windowTitle = "Ping Results (Grid)"
        }
        let newWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 450), styleMask: [.titled, .closable, .resizable, .miniaturizable, .unifiedTitleAndToolbar], backing: .buffered, defer: false)
        newWindow.center(); newWindow.setFrameAutosaveName("Ping Results Window - \(mode.rawValue)");
        // newWindow.titlebarAppearsTransparent = true; // Consider keeping this commented/removed
        newWindow.title = windowTitle // Sets the title for the *new* results window
        newWindow.contentView = NSHostingView(rootView: rootView)
        newWindow.makeKeyAndOrderFront(nil)
    }
}

