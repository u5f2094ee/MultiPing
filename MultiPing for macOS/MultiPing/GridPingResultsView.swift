import SwiftUI
import Combine // Needed for ObservableObject

// --- GridPingResultsView (Main View) ---
struct GridPingResultsView: View {
    // MARK: - Properties
    @ObservedObject var manager: PingManager
    var timeout: String
    var interval: String
    var size: String

    // MARK: - Sorting Enum (Unchanged)
    enum GridSortCriteria: String, CaseIterable, Identifiable {
        case targetValue = "Target"
        case successCount = "Success Count"
        case failureCount = "Failure Count"
        var id: String { self.rawValue }
    }

    // MARK: - UI State
    @State private var gridScale: CGFloat = 1.0
    private let minScale: CGFloat = 0.7
    private let maxScale: CGFloat = 1.5
    private let scaleStep: CGFloat = 0.1
    private var cellSpacing: CGFloat { 10 * gridScale }

    // MARK: - Sorting State (Unchanged)
    @State private var gridSortColumn: GridSortCriteria? = nil
    @State private var gridSortAscending: Bool = true

    // MARK: - Computed Properties
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150 * gridScale), spacing: cellSpacing)]
    }

    var sortedGridResults: [PingResult] { // Unchanged
        guard let sortColumn = gridSortColumn else { return manager.results }
        let resultsToSort = manager.results
        return resultsToSort.sorted { result1, result2 in
            let comparisonResult: Bool
            switch sortColumn {
            case .targetValue:
                comparisonResult = compareTargets(result1.targetValue, result1.targetType, result2.targetValue, result2.targetType)
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
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: cellSpacing) {
                    ForEach(sortedGridResults) { result in
                        GridCellView(result: result, scale: gridScale)
                    }
                }
                .padding(cellSpacing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Status Bar Area (Unchanged)
            HStack(spacing: 15) {
                StatusTextView(label: "Timeout:", value: "\(timeout) ms")
                StatusTextView(label: "Interval:", value: "\(interval) s")
                StatusTextView(label: "Size:", value: "\(size) B")
                StatusTextView(label: "Status:", value: manager.pingStatus, color: .blue, weight: .bold)
                Spacer()
                StatusTextView(label: "Reachable:", value: "\(manager.reachableCount)", color: .green, weight: .bold)
                StatusTextView(label: "Failed:", value: "\(manager.failedCount)", color: .red, weight: .bold)
            }
            .font(.callout).padding(.horizontal, 12).padding(.vertical, 5).background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                 HStack(spacing: 5) {
                    let buttonPadding: CGFloat = 7; let iconSize: CGFloat = 18

                    // --- Start/Stop & Clear Button (UPDATED LOGIC) ---
                    // Determine if the process is effectively running (pinging or paused)
                    let isEffectivelyRunning = manager.pingStatus == "Pinging..." || manager.pingStatus == "Paused"
                    Button {
                        if isEffectivelyRunning {
                            // If running or paused, the action is Stop & Clear
                            manager.stopPingTasks(clearResults: true)
                        } else {
                            // If stopped, completed, or cleared, the action is Start Ping
                            manager.startPingTasks(timeout: timeout, interval: interval, size: size)
                        }
                    } label: {
                        // Set label and icon based on the effective running state
                        Label(isEffectivelyRunning ? "Stop & Clear" : "Start Ping",
                              systemImage: isEffectivelyRunning ? "stop.circle.fill" : "play.circle.fill")
                    }
                    // Set tint based on the effective running state
                    .tint(isEffectivelyRunning ? .red : .green)
                    .padding(buttonPadding).contentShape(Rectangle())
                    // --- End Start/Stop & Clear Button Update ---

                    // --- Pause/Resume Button (UPDATED .disabled logic for consistency) ---
                    Button { manager.togglePause() } label: { Label(manager.isPaused ? "Resume" : "Pause", systemImage: manager.isPaused ? "play.circle.fill" : "pause.circle.fill") }
                    .tint(.orange)
                    // Disable if not pinging OR paused (i.e., disable if stopped, completed, cleared)
                    .disabled(!(manager.pingStatus == "Pinging..." || manager.pingStatus == "Paused"))
                    .padding(buttonPadding).contentShape(Rectangle())
                    // --- End Pause/Resume Button Update ---


                    Spacer()
                    // Sort Menu (Unchanged)
                    Menu {
                         Button("Default Order") { gridSortColumn = nil }; Divider()
                        ForEach(GridSortCriteria.allCases) { criteria in
                             Button(criteria.rawValue) {
                                 if gridSortColumn == criteria { gridSortAscending.toggle() } else { gridSortColumn = criteria
                                     switch criteria { case .targetValue: gridSortAscending = true; case .successCount, .failureCount: gridSortAscending = false }
                                 }
                             }
                         }
                    } label: { HStack { Image(systemName: "arrow.up.arrow.down.circle")
                            if let currentSort = gridSortColumn { Text("Sort: \(currentSort.rawValue)"); Image(systemName: gridSortAscending ? "arrow.up" : "arrow.down").font(.caption) } else { Text("Sort") }
                        }
                    }.menuStyle(.borderlessButton).padding(buttonPadding).contentShape(Rectangle())

                    // Scale Buttons (Unchanged)
                    Button { gridScale = max(minScale, gridScale - scaleStep) } label: { Image(systemName: "minus.magnifyingglass").font(.system(size: iconSize)) }
                    .buttonStyle(.plain).disabled(gridScale <= minScale).padding(buttonPadding).contentShape(Rectangle())
                    Button { gridScale = min(maxScale, gridScale + scaleStep) } label: { Image(systemName: "plus.magnifyingglass").font(.system(size: iconSize)) }
                    .buttonStyle(.plain).disabled(gridScale >= maxScale).padding(buttonPadding).contentShape(Rectangle())
                 }
            }
        }
        // Stop pinging (without clearing) if the view disappears
        .onDisappear {
            // Only stop if it was actively pinging or paused (not already stopped/completed)
            if manager.pingStatus == "Pinging..." || manager.pingStatus == "Paused" {
                manager.stopPingTasks(clearResults: false)
            }
        }
    }

    // MARK: - Nested GridCellView (UPDATED for notes)
    internal struct GridCellView: View {
        @ObservedObject var result: PingResult
        let scale: CGFloat
        private let baseTargetFontSizeIPv4: CGFloat = 13
        private let baseTargetFontSizeOther: CGFloat = 11
        private let baseNoteFontSize: CGFloat = 10 // New
        private let baseTimeFontSize: CGFloat = 10
        private let baseCountFontSize: CGFloat = 12
        private var minCellHeight: CGFloat { (result.note == nil ? 75 : 90) * scale } // Adjusted for note

        internal init(result: PingResult, scale: CGFloat) {
            self.result = result
            self.scale = scale
        }

        private var backgroundColor: Color {
            switch result.responseTime.lowercased() {
            case "pending", "pinging...", "paused", "stopped", "cleared", "cancelled": return Color.gray.opacity(0.3)
            default: return result.isSuccessful ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
            }
        }
        private var successColor: Color = .green
        private var failureColor: Color = .red

        private var targetDisplayNameFontSize: CGFloat {
            switch result.targetType {
            case .ipv4: return baseTargetFontSizeIPv4 * scale
            case .ipv6, .domain, .unknown: return baseTargetFontSizeOther * scale
            }
        }

        internal var body: some View {
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(result.displayName)
                    .font(.system(size: targetDisplayNameFontSize, weight: .medium, design: .monospaced))
                    .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, (result.note != nil ? 0 : 2) * scale) // Adjust padding if note exists

                if let note = result.note, !note.isEmpty { // Display note if present [cite: 5]
                    Text(note)
                        .font(.system(size: baseNoteFontSize * scale, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 2 * scale)
                }

                Text(result.responseTime)
                    .font(.system(size: baseTimeFontSize * scale, design: .monospaced))
                    .foregroundColor(result.isSuccessful ? .primary.opacity(0.8) : .secondary)
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                HStack {
                    HStack(spacing: 2 * scale) { Image(systemName: "checkmark.circle").foregroundColor(successColor); Text("\(result.successCount)").fontWeight(.bold).foregroundColor(successColor) }
                        .font(.system(size: baseCountFontSize * scale))
                    Spacer()
                    HStack(spacing: 2 * scale) { Image(systemName: "xmark.circle").foregroundColor(failureColor); Text("\(result.failureCount)").fontWeight(.bold).foregroundColor(failureColor) }
                        .font(.system(size: baseCountFontSize * scale))
                }
            }
            .padding(8 * scale).background(backgroundColor).cornerRadius(6 * scale)
            .frame(minHeight: minCellHeight).clipShape(RoundedRectangle(cornerRadius: 6 * scale))
        }
    }

    // Helper View for Status Text (Unchanged)
    struct StatusTextView: View {
        let label: String, value: String; var color: Color? = nil; var weight: Font.Weight = .regular
        var body: some View { Text(label + " ") + Text(value).fontWeight(weight).foregroundColor(color) }
    }
}

// MARK: - Extension for Sorting Helpers (Unchanged)
extension GridPingResultsView {
    private func compareTargets(_ t1Val: String, _ t1Type: TargetType, _ t2Val: String, _ t2Type: TargetType) -> Bool {
        if t1Type == .ipv4 && t2Type == .ipv4 { return compareIPAddresses(t1Val, t2Val) }
        return t1Val.localizedStandardCompare(t2Val) == .orderedAscending
    }
    private func compareIPAddresses(_ ip1: String, _ ip2: String) -> Bool {
        let p1 = ip1.split(separator: ".").compactMap { UInt32($0) }, p2 = ip2.split(separator: ".").compactMap { UInt32($0) }
        guard p1.count == 4, p2.count == 4 else { return ip1.localizedStandardCompare(ip2) == .orderedAscending }
        for i in 0..<4 { if p1[i] != p2[i] { return p1[i] < p2[i] } }; return false
    }
}
