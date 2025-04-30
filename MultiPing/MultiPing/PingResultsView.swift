import SwiftUI
import Combine

struct PingResultsView: View {
    // ObservedObject to react to changes in PingManager
    @ObservedObject var manager: PingManager
    // Settings passed from the previous view
    var timeout: String
    var interval: String
    var size: String
    // Binding to update the status display
    @Binding var pingStatus: String

    // --- State for Pinging ---
    @State private var isPaused = false
    @State private var pingTaskGroup: Task<Void, Never>? = nil

    // --- State for UI ---
    @State private var listScale: CGFloat = 1.0
    private let minScale: CGFloat = 0.7
    private let maxScale: CGFloat = 1.5
    private let scaleStep: CGFloat = 0.1

    // --- State for Sorting ---
    @State private var sortColumn: SortColumn? = nil // Initially unsorted
    @State private var sortAscending: Bool = true

    // Enum to define sortable columns
    enum SortColumn: String, CaseIterable {
        case ipAddress = "IP Address"
        case time = "Time"
        case success = "Success"
        case failures = "Failures"
        case failRate = "Fail Rate"
    }

    // Computed property to get the sorted results
    var sortedResults: [PingResult] {
        guard let sortColumn = sortColumn else {
            return manager.results // Return original order if no sort selected
        }
        let resultsToSort = manager.results
        return resultsToSort.sorted { (result1, result2) -> Bool in
            let comparisonResult: Bool
            switch sortColumn {
            case .ipAddress: comparisonResult = compareIPAddresses(result1.ip, result2.ip)
            case .time: comparisonResult = compareResponseTimes(result1.responseTime, result2.responseTime)
            case .success: comparisonResult = result1.successCount < result2.successCount
            case .failures: comparisonResult = result1.failureCount < result2.failureCount
            case .failRate: comparisonResult = result1.failureRate < result2.failureRate
            }
            return sortAscending ? comparisonResult : !comparisonResult
        }
    }


    var body: some View {
        VStack(spacing: 0) {
            // --- Header Row for the List (Passes sort state down) ---
             HeaderView(
                 scale: listScale,
                 sortColumn: $sortColumn,      // Pass binding for reading state
                 sortAscending: $sortAscending // Pass binding for reading state
             )
             .padding(.horizontal)
             .padding(.vertical, 5)
             .background(Color.gray.opacity(0.1))

            // --- Results List (Uses sortedResults) ---
            if manager.results.isEmpty {
                 Spacer()
                 Text("No IP addresses to display.").foregroundColor(.gray)
                 Spacer()
             } else {
                List {
                    ForEach(sortedResults) { result in
                        ResultRowView(result: result, scale: listScale) // Pass scale
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 25 * listScale)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar { // Toolbar configuration
            ToolbarItemGroup(placement: .secondaryAction) { /* Settings */
                HStack(spacing: 15) {
                    Text("Timeout: \(timeout) ms")
                    Text("Interval: \(interval) s")
                    Text("Size: \(size) B")
                    Text("Status: \(pingStatus)").fontWeight(.medium)
                }.font(.caption).foregroundColor(.secondary)
            }
            ToolbarItemGroup(placement: .primaryAction) { /* Buttons */
                 HStack(spacing: 5) {
                    // --- UI CHANGE 2: Adjusted Button Padding & Zoom Icon Size ---
                    let buttonPadding: CGFloat = 7 // Consistent padding
                    let zoomIconSize: CGFloat = 20 // Increased icon size

                    // Start / Stop & Clear Button
                    Button { if manager.pingStarted { stopAndClearPing() } else { startPingTasks() } } label: { Label(manager.pingStarted ? "Stop & Clear" : "Start Ping", systemImage: manager.pingStarted ? "stop.circle.fill" : "play.circle.fill") }
                        .tint(manager.pingStarted ? .red : .green).padding(buttonPadding).contentShape(Rectangle())
                    // Pause / Resume Button
                    Button { togglePause() } label: { Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.circle.fill" : "pause.circle.fill") }
                        .tint(.orange).disabled(!manager.pingStarted).padding(buttonPadding).contentShape(Rectangle())

                    Spacer() // Push zoom buttons right

                    // Zoom Buttons (Adjusted size)
                     Button { listScale = max(minScale, listScale - scaleStep) } label: {
                         Image(systemName: "minus.magnifyingglass")
                             .font(.system(size: zoomIconSize)) // Apply new size
                     }
                     .buttonStyle(.plain)
                     .disabled(listScale <= minScale).padding(buttonPadding).contentShape(Rectangle()) // Apply new padding
                     Button { listScale = min(maxScale, listScale + scaleStep) } label: {
                         Image(systemName: "plus.magnifyingglass")
                              .font(.system(size: zoomIconSize)) // Apply new size
                     }
                     .buttonStyle(.plain)
                     .disabled(listScale >= maxScale).padding(buttonPadding).contentShape(Rectangle()) // Apply new padding
                     // --- End UI Change 2 ---
                 }
            }
        }
        .onDisappear { stopPingTasks(clearResults: false) }
    }

     // --- Helper: Header View (Adjusted Fixed Column Widths) ---
     struct HeaderView: View {
         let scale: CGFloat
         @Binding var sortColumn: SortColumn?
         @Binding var sortAscending: Bool
         private let baseFontSize: CGFloat = 10
         // --- UI CHANGE 1: Adjusted Column Widths ---
         // Increased base widths again for data columns
         private let timeWidth: CGFloat = 90
         private let countWidth: CGFloat = 75
         private let rateWidth: CGFloat = 85
         // --- End UI Change 1 ---

         private func setSort(to newColumn: SortColumn) {
             if sortColumn == newColumn { sortAscending.toggle() }
             else { sortColumn = newColumn; sortAscending = true }
         }

         var body: some View {
             HStack(spacing: 5 * scale) {
                 Text(" ").frame(width: 15 * scale, alignment: .center) // Status placeholder

                 // IP Address (Flexible)
                 HeaderButton(title: SortColumn.ipAddress.rawValue, column: .ipAddress, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .ipAddress) }
                     .frame(maxWidth: .infinity, alignment: .leading) // Takes remaining space

                 // Data Columns (Scaled Fixed Width)
                 HeaderButton(title: SortColumn.time.rawValue, column: .time, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .time) }
                     .frame(width: timeWidth * scale, alignment: .trailing)

                 HeaderButton(title: SortColumn.success.rawValue, column: .success, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .success) }
                     .frame(width: countWidth * scale, alignment: .trailing)

                 HeaderButton(title: SortColumn.failures.rawValue, column: .failures, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .failures) }
                     .frame(width: countWidth * scale, alignment: .trailing)

                 HeaderButton(title: SortColumn.failRate.rawValue, column: .failRate, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .failRate) }
                     .frame(width: rateWidth * scale, alignment: .trailing)
             }
             .font(.system(size: baseFontSize * scale).weight(.semibold))
             .foregroundColor(.secondary)
             .frame(minHeight: (baseFontSize + 4) * scale)
             .buttonStyle(.borderless) // Keep headers borderless
             .contentShape(Rectangle())
         }
     }

    // --- Helper: Individual Sortable Header Button ---
    // (No changes needed here)
    struct HeaderButton: View {
        let title: String
        let column: SortColumn
        let currentSortColumn: SortColumn?
        let currentSortAscending: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(title)
                    if currentSortColumn == column {
                        Image(systemName: currentSortAscending ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                    }
                }
            }
        }
    }


    // --- Helper: Row View for List (Adjusted Fixed Column Widths & Conditional Color) ---
    struct ResultRowView: View {
        let result: PingResult
        let scale: CGFloat
        private let baseFontSize: CGFloat = 12
        // --- UI CHANGE 1: Adjusted Column Widths ---
        // Increased base widths matching header
        private let timeWidth: CGFloat = 90
        private let countWidth: CGFloat = 75
        private let rateWidth: CGFloat = 85
        // --- End UI Change 1 ---

        // Determine color based on success state
        private var statusColor: Color {
            // Use orange for intermediate states, red for failure, green for success
            if result.responseTime == "Pending" || result.responseTime == "Pinging..." || result.responseTime == "Paused" {
                return .orange
            } else {
                return result.isSuccessful ? .green : .red
            }
        }

        var body: some View {
            HStack(spacing: 5 * scale) {
                Circle()
                     .fill(statusColor) // Use calculated status color
                    .frame(width: 10 * scale, height: 10 * scale)

                // IP Address (Flexible & Colored)
                Text(result.ip)
                    .frame(maxWidth: .infinity, alignment: .leading) // Takes remaining space
                    .lineLimit(1).truncationMode(.tail)
                    // --- NEW: Conditional Color ---
                    .foregroundColor(result.isSuccessful ? .green : (statusColor == .red ? .red : .primary)) // Green if success, Red if failed, Primary otherwise

                // Data Columns (Scaled Fixed Width)
                Text(result.responseTime)
                    .frame(width: timeWidth * scale, alignment: .trailing)
                    .foregroundColor(result.isSuccessful ? .primary : .secondary) // Dim time if failed

                 // Success Count (Colored)
                 Text("\(result.successCount)")
                     .frame(width: countWidth * scale, alignment: .trailing)
                     // --- NEW: Conditional Color ---
                     .foregroundColor(result.isSuccessful ? .green : .primary) // Green if success

                 // Failure Count (Colored)
                 Text("\(result.failureCount)")
                     .frame(width: countWidth * scale, alignment: .trailing)
                     // --- NEW: Conditional Color ---
                     .foregroundColor(result.failureCount > 0 ? .red : .primary) // Red if failures > 0

                 // Fail Rate
                 Text(String(format: "%.1f%%", result.failureRate))
                     .frame(width: rateWidth * scale, alignment: .trailing)
            }
            .font(.system(size: baseFontSize * scale, design: .monospaced))
        }
    }

} // End of PingResultsView struct


// --- Extension for Logic Functions ---
// (No changes needed in the logic functions)
extension PingResultsView {
    func startPingTasks() {
        print("Start Ping requested.")
        isPaused = false
        manager.pingStarted = true
        pingStatus = "Pinging..."
        Task {
             await MainActor.run {
                 for index in manager.results.indices {
                     if manager.results.indices.contains(index) {
                         manager.results[index].responseTime = "Pinging..."
                         manager.results[index].isSuccessful = false
                     }
                 }
             }
        }
        pingTaskGroup = Task {
            await runPingLoop()
            await MainActor.run {
                 print("Ping loop finished execution.")
                 if manager.pingStarted && !isPaused {
                     manager.pingStarted = false
                     pingStatus = "Completed"
                     print("Final Status: Completed")
                     for index in manager.results.indices {
                         if manager.results.indices.contains(index) && manager.results[index].responseTime == "Pinging..." {
                             manager.results[index].responseTime = "Completed"
                         }
                     }
                 } else {
                     print("Final Status: \(pingStatus)")
                 }
            }
        }
    }

    func runPingLoop() async {
        await withTaskGroup(of: Void.self) { group in
            for index in manager.results.indices {
                guard !Task.isCancelled && manager.pingStarted && !isPaused else { break }
                guard manager.results.indices.contains(index) else { continue }
                let ip = manager.results[index].ip

                group.addTask {
                    while !Task.isCancelled && manager.pingStarted && !isPaused {
                        let currentResponseTime = await self.ping(ip: ip)
                        let wasCancelledDuringPing = Task.isCancelled

                        if !wasCancelledDuringPing && manager.pingStarted && !isPaused {
                            let currentSuccess = ["Timeout", "Error", "No output", "Failed", "Host unknown", "Invalid IP", "Network down", "Cancelled"].allSatisfy { currentResponseTime != $0 }

                            await MainActor.run {
                                guard manager.results.indices.contains(index), manager.pingStarted, !isPaused else { return }
                                manager.results[index].responseTime = currentResponseTime
                                manager.results[index].isSuccessful = currentSuccess
                                if currentSuccess { manager.results[index].successCount += 1 }
                                else {
                                     if currentResponseTime != "Paused" && currentResponseTime != "Stopped" && currentResponseTime != "Cancelled" {
                                        manager.results[index].failureCount += 1
                                     }
                                }
                                let totalPings = manager.results[index].successCount + manager.results[index].failureCount
                                manager.results[index].failureRate = totalPings > 0 ? (Double(manager.results[index].failureCount) / Double(totalPings)) * 100.0 : 0.0
                            }
                        } else {
                            print("Loop for \(ip) interrupted. Cancelled=\(Task.isCancelled || wasCancelledDuringPing), Started=\(manager.pingStarted), Paused=\(isPaused)")
                            break
                        }

                        guard !Task.isCancelled && manager.pingStarted && !isPaused else { break }
                        do {
                            let intervalSeconds = Int64(self.interval) ?? 5
                            let nanoseconds = UInt64(max(1, intervalSeconds) * 1_000_000_000)
                            try await Task.sleep(nanoseconds: nanoseconds)
                        } catch { break }
                    }
                    print("Exited ping loop task for IP \(ip).")
                }
            }
            if Task.isCancelled || !manager.pingStarted || isPaused {
                print("Task group finishing prematurely. Cancelling all remaining tasks.")
                group.cancelAll()
            } else {
                 print("Task group finishing normally.")
            }
        }
    }


    func togglePause() {
        guard manager.pingStarted else { return }
        isPaused.toggle()
        pingStatus = isPaused ? "Paused" : "Pinging..."
        print("Toggled Pause: \(isPaused)")
        if isPaused {
            pingTaskGroup?.cancel()
            pingTaskGroup = nil
            print("Ping task group cancelled for Pause.")
            Task {
                await MainActor.run {
                    for index in manager.results.indices {
                        if manager.results.indices.contains(index) && manager.results[index].responseTime == "Pinging..." {
                            manager.results[index].responseTime = "Paused"
                        }
                    }
                }
            }
        } else {
             print("Resuming ping...")
             manager.pingStarted = true
             startPingTasks()
        }
    }


    func stopPingTasks(clearResults: Bool) {
        print("Stop Ping requested. Clear Results: \(clearResults)")
        let wasStarted = manager.pingStarted
        manager.pingStarted = false
        isPaused = false
        pingStatus = clearResults ? "Cleared" : "Stopped"
        pingTaskGroup?.cancel()
        pingTaskGroup = nil
        print("Ping task group cancelled.")

        if wasStarted || clearResults {
            Task {
                await MainActor.run {
                    for index in manager.results.indices {
                         guard manager.results.indices.contains(index) else { continue }
                        let currentStatus = manager.results[index].responseTime
                        if clearResults || currentStatus == "Pinging..." || currentStatus == "Paused" || currentStatus == "Pending" {
                            manager.results[index].responseTime = clearResults ? "Cleared" : "Stopped"
                            manager.results[index].isSuccessful = false
                        }
                        if clearResults {
                            manager.results[index].successCount = 0
                            manager.results[index].failureCount = 0
                            manager.results[index].failureRate = 0.0
                        }
                    }
                     pingStatus = clearResults ? "Cleared" : "Stopped"
                }
            }
        }
    }

    func stopAndClearPing() {
        stopPingTasks(clearResults: true)
    }


    func ping(ip: String) async -> String {
        guard !ip.isEmpty, isValidIPAddress(ip) else { return "Invalid IP" }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        let timeoutMs = Int(timeout) ?? 1000
        let packetSize = max(0, Int(size) ?? 56)
        task.arguments = ["-c", "1", "-W", String(timeoutMs), "-s", String(packetSize), ip]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        var processOutput: String? = nil

        do {
            if Task.isCancelled { return "Cancelled" }
            try task.run()
            async let waitTask: Void = task.waitUntilExit()
            async let readDataTask: Data? = pipe.fileHandleForReading.readToEnd()
            let effectiveTimeoutMs = max(1, timeoutMs)
            async let timeoutTask: Void = Task.sleep(nanoseconds: UInt64(effectiveTimeoutMs + 500) * 1_000_000)

            _ = await (try? readDataTask, waitTask, timeoutTask)

             if Task.isCancelled {
                 print("Ping task cancelled for \(ip) during execution.")
                 if task.isRunning { task.terminate() }
                 return "Cancelled"
             }
            if task.isRunning { task.terminate(); return "Timeout" }
            guard let data = try? await readDataTask, let output = String(data: data, encoding: .utf8) else {
                 return task.terminationStatus == 0 ? "No output" : "Failed"
            }
            processOutput = output
            if task.terminationStatus != 0 && !output.contains("time=") { return parsePingError(output) }
            return parsePingOutput(output)
        } catch {
             if Task.isCancelled { return "Cancelled" }
             print("Error running ping process for \(ip): \(error)")
             if let output = processOutput { return parsePingError(output) }
             return "Error"
        }
    }
     func isValidIPAddress(_ ipString: String) -> Bool {
         let parts = ipString.split(separator: ".")
         guard parts.count == 4 else { return false }
         return parts.allSatisfy { part in
             guard let number = Int(part) else { return false }
             return number >= 0 && number <= 255
         }
     }
    func parsePingOutput(_ output: String) -> String {
         let regex = try? NSRegularExpression(pattern: #"time=(\d+(\.\d+)?)\s*ms"#, options: [])
         if let match = regex?.firstMatch(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count)),
            let range = Range(match.range(at: 1), in: output) {
             return "\(String(output[range])) ms"
         } else { return "Failed" }
    }
     func parsePingError(_ output: String) -> String {
         if output.contains("timeout") || output.contains("Request timeout") { return "Timeout" }
         else if output.contains("cannot resolve") || output.contains("Unknown host") { return "Host unknown" }
         else if output.contains("Network is unreachable") { return "Network down" }
         else if output.contains("sendto: No route to host") { return "No route" }
         else { return "Failed" }
     }

    // --- Sorting Helper Functions ---
    private func parseTimeValue(_ timeString: String) -> Double {
        switch timeString.lowercased() {
        case "timeout", "failed", "error", "no output", "host unknown", "invalid ip", "network down", "no route", "cancelled":
            return Double.infinity
        case "pending", "pinging...", "paused", "stopped", "cleared":
             return Double.infinity - 1
        default:
            let components = timeString.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            let numericPart = components.first(where: { !$0.isEmpty && Double($0) != nil }) ?? ""
            return Double(numericPart) ?? Double.infinity
        }
    }
    private func compareResponseTimes(_ time1: String, _ time2: String) -> Bool {
        return parseTimeValue(time1) < parseTimeValue(time2)
    }
    private func compareIPAddresses(_ ip1: String, _ ip2: String) -> Bool {
        let parts1 = ip1.split(separator: ".").compactMap { UInt32($0) }
        let parts2 = ip2.split(separator: ".").compactMap { UInt32($0) }
        guard parts1.count == 4, parts2.count == 4 else { return ip1 < ip2 }
        for i in 0..<4 { if parts1[i] != parts2[i] { return parts1[i] < parts2[i] } }
        return false
    }
}

