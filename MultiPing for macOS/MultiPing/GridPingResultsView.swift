import SwiftUI
import Combine // Needed for ObservableObject

// --- GridPingResultsView (Main View) ---
struct GridPingResultsView: View {
    // MARK: - Properties
    @ObservedObject var manager: PingManager
    var timeout: String
    var interval: String
    var size: String

    // MARK: - Sorting Enum
    enum GridSortCriteria: String, CaseIterable, Identifiable {
        case ipAddress = "IP Address"
        case successCount = "Success Count"
        case failureCount = "Failure Count"
        var id: String { self.rawValue }
    }

    // MARK: - UI State
    @State private var gridScale: CGFloat = 1.0
    private let minScale: CGFloat = 0.7
    private let maxScale: CGFloat = 1.5
    private let scaleStep: CGFloat = 0.1

    // MARK: - Sorting State
    @State private var gridSortColumn: GridSortCriteria? = nil
    @State private var gridSortAscending: Bool = true

    // MARK: - Computed Properties
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140 * gridScale))]
    }

    var sortedGridResults: [PingResult] {
        guard let sortColumn = gridSortColumn else { return manager.results }
        let resultsToSort = manager.results
        return resultsToSort.sorted { result1, result2 in
            let comparisonResult: Bool
            switch sortColumn {
            case .ipAddress:
                comparisonResult = compareIPAddresses(result1.ip, result2.ip)
            case .successCount:
                comparisonResult = result1.successCount < result2.successCount
            case .failureCount:
                comparisonResult = result1.failureCount < result2.failureCount
            }
            return gridSortAscending ? comparisonResult : !comparisonResult
        }
    }

    // MARK: - Body
    var body: some View {
        // Main container stack
        VStack(spacing: 0) { // No spacing between ScrollView and Status Bar
            // Scrollable area for the grid
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 10 * gridScale) {
                    ForEach(sortedGridResults) { result in
                        GridCellView(result: result, scale: gridScale)
                    }
                }
                .padding() // Padding inside the scroll view
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow ScrollView to expand

            // --- Status Bar Area ---
            HStack(spacing: 15) { // Arrange status items horizontally
                StatusTextView(label: "Timeout:", value: "\(timeout) ms")
                StatusTextView(label: "Interval:", value: "\(interval) s")
                StatusTextView(label: "Size:", value: "\(size) B")
                // --- MODIFIED: Apply bold weight and blue color to Status value ---
                StatusTextView(label: "Status:", value: manager.pingStatus, color: .blue, weight: .bold)
                // --- END MODIFIED ---

                Spacer() // Push counts to the right

                // Emphasized Reachable/Failed counts
                StatusTextView(label: "Reachable:", value: "\(manager.reachableCount)", color: .green, weight: .bold)
                StatusTextView(label: "Failed:", value: "\(manager.failedCount)", color: .red, weight: .bold)
            }
            .font(.callout) // Set base font size for the status bar
            .padding(.horizontal, 12) // Horizontal padding for the bar
            .padding(.vertical, 5)    // Vertical padding for the bar
            .background(.bar)         // Use a standard bar background material
            // --- END Status Bar Area ---
        }
        .toolbar { // Toolbar now only contains primary action buttons
            // Toolbar Group for primary actions (buttons - unchanged)
            ToolbarItemGroup(placement: .primaryAction) {
                 HStack(spacing: 5) {
                    let buttonPadding: CGFloat = 7
                    let iconSize: CGFloat = 18

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

                    Spacer()

                    // Sorting Menu
                    Menu {
                         Button("Default Order") { gridSortColumn = nil }
                         Divider()
                        ForEach(GridSortCriteria.allCases) { criteria in
                             Button(criteria.rawValue) {
                                 if gridSortColumn == criteria {
                                     gridSortAscending.toggle()
                                 } else {
                                     gridSortColumn = criteria
                                     switch criteria {
                                     case .ipAddress: gridSortAscending = true
                                     case .successCount, .failureCount: gridSortAscending = false
                                     }
                                 }
                             }
                         }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down.circle")
                            if let currentSort = gridSortColumn {
                                Text("Sort: \(currentSort.rawValue)")
                                Image(systemName: gridSortAscending ? "arrow.up" : "arrow.down").font(.caption)
                            } else { Text("Sort") }
                        }
                    }
                    .menuStyle(.borderlessButton).padding(buttonPadding).contentShape(Rectangle())

                    // Zoom Buttons
                    Button { gridScale = max(minScale, gridScale - scaleStep) } label: {
                        Image(systemName: "minus.magnifyingglass").font(.system(size: iconSize))
                    }
                    .buttonStyle(.plain).disabled(gridScale <= minScale)
                    .padding(buttonPadding).contentShape(Rectangle())

                    Button { gridScale = min(maxScale, gridScale + scaleStep) } label: {
                        Image(systemName: "plus.magnifyingglass").font(.system(size: iconSize))
                    }
                    .buttonStyle(.plain).disabled(gridScale >= maxScale)
                    .padding(buttonPadding).contentShape(Rectangle())
                 }
            }
        }
        .onDisappear {
            if manager.pingStarted { manager.stopPingTasks(clearResults: false) }
        }
    }

    // MARK: - Nested GridCellView (Unchanged)
    internal struct GridCellView: View {
        @ObservedObject var result: PingResult
        let scale: CGFloat

        internal init(result: PingResult, scale: CGFloat) {
             self.result = result
             self.scale = scale
         }

        private var backgroundColor: Color {
            switch result.responseTime.lowercased() {
            case "pending", "pinging...", "paused", "stopped", "cleared", "cancelled":
                return Color.gray.opacity(0.3)
            default:
                return result.isSuccessful ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
            }
        }
        private var successColor: Color = .green
        private var failureColor: Color = .red
        private let ipFontSize: CGFloat = 12
        private let timeFontSize: CGFloat = 11
        private let countFontSize: CGFloat = 13

        internal var body: some View {
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(result.ip)
                    .font(.system(size: ipFontSize * scale, weight: .medium, design: .monospaced))
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(result.responseTime)
                    .font(.system(size: timeFontSize * scale, design: .monospaced))
                    .foregroundColor(result.isSuccessful ? .primary.opacity(0.8) : .secondary)
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    HStack(spacing: 2 * scale) {
                        Image(systemName: "checkmark.circle").foregroundColor(successColor)
                        Text("\(result.successCount)").fontWeight(.bold).foregroundColor(successColor)
                    }
                    .font(.system(size: countFontSize * scale))
                    Spacer()
                     HStack(spacing: 2 * scale) {
                        Image(systemName: "xmark.circle").foregroundColor(failureColor)
                        Text("\(result.failureCount)").fontWeight(.bold).foregroundColor(failureColor)
                    }
                    .font(.system(size: countFontSize * scale))
                }
            }
            .padding(8 * scale)
            .background(backgroundColor)
            .cornerRadius(6 * scale)
            .frame(minWidth: 120 * scale, minHeight: 65 * scale)
        }
    }

    // Helper View for Status Text (Unchanged)
    // It respects the font set on its container unless weight/color are overridden
    struct StatusTextView: View {
        let label: String
        let value: String
        var color: Color? = nil
        var weight: Font.Weight = .regular // Default to regular weight

        var body: some View {
            // Label uses container font. Value uses container font + optional bold/color.
            Text(label + " ") + Text(value).fontWeight(weight).foregroundColor(color)
        }
    }

} // End of GridPingResultsView struct


// MARK: - Extension for Sorting Helpers (Unchanged)
extension GridPingResultsView {
    private func compareIPAddresses(_ ip1: String, _ ip2: String) -> Bool {
        let p1 = ip1.split(separator: ".").compactMap { UInt32($0) }
        let p2 = ip2.split(separator: ".").compactMap { UInt32($0) }
        guard p1.count == 4, p2.count == 4 else { return ip1 < ip2 }
        for i in 0..<4 {
            if p1[i] != p2[i] { return p1[i] < p2[i] }
        }
        return false
    }
}

