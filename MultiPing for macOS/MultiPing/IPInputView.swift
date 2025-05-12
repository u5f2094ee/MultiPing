import SwiftUI
import AppKit
import Foundation // Needed for ceil()

// Enum for View Modes (Unchanged)
enum ResultsViewMode: String, CaseIterable, Identifiable {
    case list = "≡ List Layout"
    case grid = "# Grid Layout"
    var id: String { self.rawValue }
}

struct IPInputView: View {
    @ObservedObject var manager: PingManager
    @State var timeout: String = "2000"
    @State var interval: String = "10"
    @State var size: String = "32"
    @State private var selectedViewMode: ResultsViewMode = .grid

    var validTargetCount: Int {
        return parseTargets(from: manager.ipInput).count
    }

    var suggestedInterval: Int {
        guard validTargetCount > 0 else { return 1 }
        let rawSuggestion = Double(validTargetCount) / 10.0
        let roundedUpSuggestion = ceil(rawSuggestion)
        return max(1, Int(roundedUpSuggestion))
    }

    var body: some View {
        VStack(spacing: 15) {
            // Settings Row (Unchanged)
            HStack(alignment: .bottom, spacing: 15) {
                VStack(alignment: .leading) { Text("Timeout (ms)").font(.caption); TextField("2000", text: $timeout).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80) }
                VStack(alignment: .leading) { Text("Interval (s)").font(.caption); TextField("", text: $interval).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80) }
                VStack(alignment: .leading) { Text("Size (bytes)").font(.caption); TextField("32", text: $size).textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80) }
                Spacer()
            }.padding(.top).padding(.horizontal)

            // Interval Notice Text (Unchanged)
            Text("Notice:\nTo avoid inaccurate results when pinging a large number of Targets,Please set the interval (seconds) to at least one-tenth of the total Target count \n(e.g., 10s for 100 Targets, 20s for 200 Targets).")
                .font(.footnote).fontWeight(.bold).foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal).padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Target Input Area Label (Unchanged)
            Text("Enter Targets (Each target on a separate line)").font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $manager.ipInput).frame(maxWidth: .infinity, maxHeight: .infinity).border(Color.gray.opacity(0.5), width: 1)
                // Using your updated placeholder text
                if manager.ipInput.isEmpty { Text("e.g.,\n\n8.8.8.8\n2001:db8::1\nexample.com\n192.168.1.1\n::1\n10.0.0.1\n2001:db8::1\n123.com").foregroundColor(.secondary).padding(.leading, 5).padding(.top, 8).allowsHitTesting(false) }
            }.padding(.horizontal).layoutPriority(1)

            // Bottom Row (Controls - Unchanged)
            HStack {
                Text("Count of Targets: \(validTargetCount)")
                    .font(.callout).foregroundColor(.secondary).padding(.trailing, 20)
                Text("                           Monitoring layout:").font(.callout).padding(.trailing, 10)
                Picker("", selection: $selectedViewMode) {
                    ForEach(ResultsViewMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }.pickerStyle(.segmented).frame(maxWidth: 200)
                Spacer()
                Button("Start ping") { prepareAndStartPing() }
                    .buttonStyle(.borderedProminent).disabled(validTargetCount == 0)
            }.padding(.horizontal).padding(.bottom)

        }
        .padding(.top).frame(minWidth: 500, minHeight: 380)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text("Targets Collector").font(.headline).padding(.leading, 5)
            }
        }
        .onChange(of: validTargetCount) { _ in interval = String(suggestedInterval) }
        .onAppear { interval = String(suggestedInterval) }
    }

    func validateSettings() { // Unchanged
        if Int(timeout) == nil { timeout = "2000" }
        if Int(interval) == nil || (Int(interval) ?? 1) < 1 { interval = "1" }
        if Int(size) == nil { size = "32" }
        if let timeoutValue = Int(timeout), let intervalValue = Int(interval) {
            if timeoutValue > intervalValue * 1000 { timeout = String(intervalValue * 1000); }
        }
    }
    
    /// Identifies the type of a given target string (IPv4, IPv6, or domain).
    private func identifyTargetType(_ targetString: String) -> TargetType {
        let trimmedTarget = targetString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for IPv4 (standard 4 octets, 0-255)
        let ipv4Parts = trimmedTarget.split(separator: ".")
        if ipv4Parts.count == 4 && ipv4Parts.allSatisfy({ part in
            // Ensure part is purely numeric and within range
            if let n = Int(part), String(n) == part, n >= 0 && n <= 255 { return true }
            return false
        }) {
            // Ensure the entire string matches the IPv4 pattern (no trailing characters)
            if ipv4Parts.joined(separator: ".").count == trimmedTarget.count {
                 return .ipv4
            }
        }

        // Check for IPv6: More inclusive - if it contains a colon and wasn't identified as IPv4.
        // This relies on ping6 to perform the ultimate validation for complex IPv6 notations.
        if trimmedTarget.contains(":") {
            // Basic sanity check: avoid classifying common URLs with ports as IPv6 by mistake.
            // This is a heuristic. A very complex URL might still pass.
            if !trimmedTarget.lowercased().hasPrefix("http://") &&
               !trimmedTarget.lowercased().hasPrefix("https://") &&
               trimmedTarget.components(separatedBy: "/").count == 1 && // No path segments
               trimmedTarget.components(separatedBy: "?").count == 1 && // No query params
               trimmedTarget.components(separatedBy: "#").count == 1 {  // No fragments
                 return .ipv6
            }
        }
        
        // Default to domain if not clearly IPv4 or likely IPv6.
        // This includes hostnames, FQDNs, and potentially malformed IPs that ping might try to resolve.
        // Requirements state no strict domain validation, rely on ping command.
        if !trimmedTarget.isEmpty && !trimmedTarget.contains(" ") {
            return .domain
        }
        
        return .unknown // Fallback for empty or space-containing strings after trimming (should be rare)
    }

    private func parseTargets(from input: String) -> [(value: String, type: TargetType)] { // Unchanged
        return input.split { $0.isNewline || $0 == "," }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { (value: $0, type: identifyTargetType($0)) }
    }

    func prepareAndStartPing() { // Unchanged
        validateSettings()
        let inputWindow = NSApp.keyWindow
        manager.results.removeAll()
        manager.pingStarted = false
        let targets = parseTargets(from: manager.ipInput)
        guard !targets.isEmpty else { return }
        for targetInfo in targets {
            manager.results.append(PingResult(targetValue: targetInfo.value,
                                              targetType: targetInfo.type,
                                              responseTime: "Pending",
                                              successCount: 0, failureCount: 0,
                                              failureRate: 0.0, isSuccessful: false))
        }
        manager.startPingTasks(timeout: self.timeout, interval: self.interval, size: self.size)
        openResultsWindow(mode: selectedViewMode)
        inputWindow?.close()
    }

    func openResultsWindow(mode: ResultsViewMode) { // Unchanged
        let rootView: AnyView
        let windowTitle: String
        switch mode {
        case .list: rootView = AnyView(PingResultsView(manager: manager, timeout: timeout, interval: interval, size: size)); windowTitle = "Ping Results (List)"
        case .grid: rootView = AnyView(GridPingResultsView(manager: manager, timeout: timeout, interval: interval, size: size)); windowTitle = "Ping Results (Grid)"
        }
        let newWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 450), styleMask: [.titled, .closable, .resizable, .miniaturizable, .unifiedTitleAndToolbar], backing: .buffered, defer: false)
        newWindow.center(); newWindow.setFrameAutosaveName("Ping Results Window - \(mode.rawValue)");
        newWindow.title = windowTitle
        newWindow.contentView = NSHostingView(rootView: rootView)
        newWindow.makeKeyAndOrderFront(nil)
    }
}

