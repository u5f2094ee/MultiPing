import SwiftUI

// List View - Refactored to use PingManager for logic
struct PingResultsView: View {
    // MARK: - Properties
    @ObservedObject var manager: PingManager
    var timeout: String
    var interval: String
    var size: String

    // MARK: - UI State
    @State private var sortColumn: SortColumn? = nil
    @State private var sortAscending: Bool = true
    @State private var listScale: CGFloat = 1.0
    private let minScale: CGFloat = 0.7
    private let maxScale: CGFloat = 1.5
    private let scaleStep: CGFloat = 0.1

    // MARK: - Sorting Enum
    enum SortColumn: String, CaseIterable, Equatable {
        case ipAddress = "IP Address"
        case time = "Time"
        case success = "Success"
        case failures = "Failures"
        case failRate = "Fail Rate"
    }

    // MARK: - Computed Sorted Results
    var sortedResults: [PingResult] {
        guard let sortColumn = sortColumn else { return manager.results }
        let resultsToSort = manager.results
        return resultsToSort.sorted { result1, result2 in
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

    // MARK: - Body
    var body: some View {
        // Main container stack
        VStack(spacing: 0) { // Ensure no spacing between List and Status Bar
            // --- Header Row ---
             HeaderView(
                 scale: listScale,
                 sortColumn: $sortColumn,
                 sortAscending: $sortAscending
             )
             .padding(.horizontal).padding(.vertical, 5).background(Color.gray.opacity(0.1))

            // --- Results List ---
            if manager.results.isEmpty {
                 Spacer(); Text("No IP addresses to display.").foregroundColor(.gray); Spacer()
             } else {
                List {
                    ForEach(sortedResults) { result in
                        ResultRowView(result: result, scale: listScale)
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 25 * listScale) // Adjust row height based on scale
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow list to expand
            }

            // --- MODIFIED: Status Bar Area ---
            HStack(spacing: 15) { // Arrange status items horizontally
                StatusTextView(label: "Timeout:", value: "\(timeout) ms")
                StatusTextView(label: "Interval:", value: "\(interval) s")
                StatusTextView(label: "Size:", value: "\(size) B")
                StatusTextView(label: "Status:", value: manager.pingStatus, color: .blue, weight: .bold)

                Spacer() // Push Counts to the right

                // --- NEW: Add Reachable/Failed Counts ---
                StatusTextView(label: "Reachable:", value: "\(manager.reachableCount)", color: .green, weight: .bold)
                StatusTextView(label: "Failed:", value: "\(manager.failedCount)", color: .red, weight: .bold)
                // --- END NEW ---
            }
            .font(.callout) // Set base font size for the entire status bar
            .padding(.horizontal, 12) // Horizontal padding
            .padding(.vertical, 5)    // Vertical padding
            .background(.bar)         // Standard bar background material
            // --- END MODIFIED: Status Bar Area ---
        }
        .toolbar { // Toolbar now only contains primary action buttons
            // Toolbar Group for primary actions (buttons - unchanged)
            ToolbarItemGroup(placement: .primaryAction) {
                 HStack(spacing: 5) {
                    let buttonPadding: CGFloat = 7; let iconSize: CGFloat = 18

                    // Start/Stop, Pause/Resume Buttons
                    Button {
                        if manager.pingStarted { manager.stopPingTasks(clearResults: true) }
                        else { manager.startPingTasks(timeout: timeout, interval: interval, size: size) }
                    } label: {
                        Label(manager.pingStarted ? "Stop & Clear" : "Start Ping",
                              systemImage: manager.pingStarted ? "stop.circle.fill" : "play.circle.fill")
                    }
                    .tint(manager.pingStarted ? .red : .green)
                    .padding(buttonPadding).contentShape(Rectangle())

                    Button { manager.togglePause() } label: {
                        Label(manager.isPaused ? "Resume" : "Pause",
                              systemImage: manager.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    }
                    .tint(.orange).disabled(!manager.pingStarted)
                    .padding(buttonPadding).contentShape(Rectangle())

                    Spacer() // Keep spacer to push zoom buttons right

                    // Zoom Buttons (List view doesn't have sorting menu)
                    Button { listScale = max(minScale, listScale - scaleStep) } label: {
                        Image(systemName: "minus.magnifyingglass").font(.system(size: iconSize))
                    }
                    .buttonStyle(.plain).disabled(listScale <= minScale)
                    .padding(buttonPadding).contentShape(Rectangle())

                    Button { listScale = min(maxScale, listScale + scaleStep) } label: {
                        Image(systemName: "plus.magnifyingglass").font(.system(size: iconSize))
                    }
                    .buttonStyle(.plain).disabled(listScale >= maxScale)
                    .padding(buttonPadding).contentShape(Rectangle())
                 }
            }
        }
        .onDisappear {
            // Stop pings (without clearing) if view disappears while running
            if manager.pingStarted { manager.stopPingTasks(clearResults: false) }
        }
    }

     // MARK: - Nested Helper Views (Header, Row)
     struct HeaderView: View {
         let scale: CGFloat
         @Binding var sortColumn: SortColumn?
         @Binding var sortAscending: Bool
         private let baseFontSize: CGFloat = 10
         private let timeWidth: CGFloat = 80
         private let countWidth: CGFloat = 65
         private let rateWidth: CGFloat = 75

         private func setSort(to newColumn: SortColumn) {
             if sortColumn == newColumn { sortAscending.toggle() }
             else { sortColumn = newColumn; sortAscending = true }
         }

         var body: some View {
             HStack(spacing: 5 * scale) {
                 Text(" ").frame(width: 15 * scale, alignment: .center) // Status dot placeholder
                 HeaderButton(title: SortColumn.ipAddress.rawValue, column: .ipAddress, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .ipAddress) }.frame(maxWidth: .infinity, alignment: .leading)
                 HeaderButton(title: SortColumn.time.rawValue, column: .time, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .time) }.frame(width: timeWidth * scale, alignment: .trailing)
                 HeaderButton(title: SortColumn.success.rawValue, column: .success, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .success) }.frame(width: countWidth * scale, alignment: .trailing)
                 HeaderButton(title: SortColumn.failures.rawValue, column: .failures, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .failures) }.frame(width: countWidth * scale, alignment: .trailing)
                 HeaderButton(title: SortColumn.failRate.rawValue, column: .failRate, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .failRate) }.frame(width: rateWidth * scale, alignment: .trailing)
             }
             .font(.system(size: baseFontSize * scale).weight(.semibold)).foregroundColor(.secondary).frame(minHeight: (baseFontSize + 4) * scale).buttonStyle(.borderless).contentShape(Rectangle())
         }
     }

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
                        Image(systemName: currentSortAscending ? "arrow.up" : "arrow.down").font(.system(size: 8))
                    }
                }
            }
        }
    }

    struct ResultRowView: View {
        @ObservedObject var result: PingResult
        let scale: CGFloat
        private let baseFontSize: CGFloat = 12
        private let timeWidth: CGFloat = 80
        private let countWidth: CGFloat = 65
        private let rateWidth: CGFloat = 75

        private var statusColor: Color {
            switch result.responseTime.lowercased() {
            case "pending", "pinging...", "paused", "stopped", "cleared", "cancelled": return .orange
            default: return result.isSuccessful ? .green : .red
            }
        }

        var body: some View {
            HStack(spacing: 5 * scale) {
                Circle().fill(statusColor).frame(width: 10 * scale, height: 10 * scale)
                Text(result.ip).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1).truncationMode(.tail).foregroundColor(result.isSuccessful ? .green : (statusColor == .red ? .red : .primary))
                Text(result.responseTime).frame(width: timeWidth * scale, alignment: .trailing).foregroundColor(result.isSuccessful ? .primary : .secondary)
                 Text("\(result.successCount)").fontWeight(.bold).frame(width: countWidth * scale, alignment: .trailing).foregroundColor(result.isSuccessful ? .green : .primary)
                 Text("\(result.failureCount)").fontWeight(.bold).frame(width: countWidth * scale, alignment: .trailing).foregroundColor(result.failureCount > 0 ? .red : .primary)
                 Text(String(format: "%.1f%%", result.failureRate)).frame(width: rateWidth * scale, alignment: .trailing)
            }
            .font(.system(size: baseFontSize * scale, design: .monospaced))
        }
    }

    // Helper View for Status Text (Copied from Grid View)
    struct StatusTextView: View {
        let label: String
        let value: String
        var color: Color? = nil // Optional color for the value text
        var weight: Font.Weight = .regular // Optional font weight for the value text

        var body: some View {
            // Label uses container font. Value uses container font + optional bold/color.
            Text(label + " ") + Text(value).fontWeight(weight).foregroundColor(color)
        }
    }

} // End of PingResultsView struct


// MARK: - Extension for Sorting Helpers
extension PingResultsView {
    private func parseTimeValue(_ timeString: String) -> Double {
        switch timeString.lowercased() {
        case "timeout", "failed", "error", "no output", "host unknown", "invalid ip", "network down", "no route", "cancelled": return Double.infinity
        case "pending", "pinging...", "paused", "stopped", "cleared": return Double.infinity - 1
        default: let c = timeString.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted); let n = c.first(where: { !$0.isEmpty && Double($0) != nil }) ?? ""; return Double(n) ?? Double.infinity
        }
    }
    private func compareResponseTimes(_ time1: String, _ time2: String) -> Bool { return parseTimeValue(time1) < parseTimeValue(time2) }
    private func compareIPAddresses(_ ip1: String, _ ip2: String) -> Bool {
        let p1 = ip1.split(separator: ".").compactMap { UInt32($0) }; let p2 = ip2.split(separator: ".").compactMap { UInt32($0) }; guard p1.count == 4, p2.count == 4 else { return ip1 < ip2 }; for i in 0..<4 { if p1[i] != p2[i] { return p1[i] < p2[i] } }; return false
    }
}

