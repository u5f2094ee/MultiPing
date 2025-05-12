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

    // MARK: - Sorting Enum (Unchanged)
    enum SortColumn: String, CaseIterable, Equatable {
        case targetValue = "Target"
        case time = "Time"
        case success = "Success"
        case failures = "Failures"
        case failRate = "Fail Rate"
    }

    // MARK: - Computed Sorted Results (Unchanged)
    var sortedResults: [PingResult] {
        guard let sortColumn = sortColumn else { return manager.results }
        let resultsToSort = manager.results
        return resultsToSort.sorted { result1, result2 in
            let comparisonResult: Bool
            switch sortColumn {
            case .targetValue:
                comparisonResult = compareTargets(result1.targetValue, result1.targetType, result2.targetValue, result2.targetType)
            case .time:
                comparisonResult = compareResponseTimes(result1.responseTime, result2.responseTime)
            case .success:
                comparisonResult = result1.successCount < result2.successCount
            case .failures:
                comparisonResult = result1.failureCount < result2.failureCount
            case .failRate:
                comparisonResult = result1.failureRate < result2.failureRate
            }
            return sortAscending ? comparisonResult : !comparisonResult
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
             HeaderView(
                 sortColumn: $sortColumn,
                 sortAscending: $sortAscending
             )
             .environment(\.listScale, listScale)
             .padding(.horizontal).padding(.vertical, 5).background(Color.gray.opacity(0.1))

            if manager.results.isEmpty {
                 Spacer(); Text("No targets to display.").foregroundColor(.gray); Spacer()
             } else {
                List {
                    ForEach(sortedResults) { result in
                        ResultRowView(result: result)
                           .environment(\.listScale, listScale)
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 25 * listScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

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
                    let isEffectivelyRunning = manager.pingStatus == "Pinging..." || manager.pingStatus == "Paused"
                    Button {
                        if isEffectivelyRunning {
                            manager.stopPingTasks(clearResults: true)
                        } else {
                            manager.startPingTasks(timeout: timeout, interval: interval, size: size)
                        }
                    } label: {
                        Label(isEffectivelyRunning ? "Stop & Clear" : "Start Ping",
                              systemImage: isEffectivelyRunning ? "stop.circle.fill" : "play.circle.fill")
                    }
                    .tint(isEffectivelyRunning ? .red : .green)
                    .padding(buttonPadding).contentShape(Rectangle())
                    // --- End Start/Stop & Clear Button Update ---

                    // Pause/Resume Button (Logic for disabled state was already correct)
                    Button { manager.togglePause() } label: { Label(manager.isPaused ? "Resume" : "Pause", systemImage: manager.isPaused ? "play.circle.fill" : "pause.circle.fill") }
                    .tint(.orange)
                    .disabled(!(manager.pingStatus == "Pinging..." || manager.pingStatus == "Paused")) // Disabled if not pinging or paused
                    .padding(buttonPadding).contentShape(Rectangle())

                    Spacer()
                    // Scale Buttons (Unchanged)
                    Button { listScale = max(minScale, listScale - scaleStep) } label: { Image(systemName: "minus.magnifyingglass").font(.system(size: iconSize)) }
                    .buttonStyle(.plain).disabled(listScale <= minScale).padding(buttonPadding).contentShape(Rectangle())
                    Button { listScale = min(maxScale, listScale + scaleStep) } label: { Image(systemName: "plus.magnifyingglass").font(.system(size: iconSize)) }
                    .buttonStyle(.plain).disabled(listScale >= maxScale).padding(buttonPadding).contentShape(Rectangle())
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

     // MARK: - Nested Helper Views (Header, Row - Unchanged)

     struct HeaderView: View {
         @Environment(\.listScale) var scale: CGFloat
         @Binding var sortColumn: SortColumn?
         @Binding var sortAscending: Bool

         private let statusDotWidth: CGFloat = 15; private let timeWidth: CGFloat = 140
         private let successWidth: CGFloat = 75; private let failuresWidth: CGFloat = 75
         private let failRateWidth: CGFloat = 85; private let spacing: CGFloat = 8
         private let baseFontSize: CGFloat = 10

         private func setSort(to newColumn: SortColumn) {
             if sortColumn == newColumn { sortAscending.toggle() }
             else { sortColumn = newColumn
                 switch newColumn {
                 case .targetValue: sortAscending = true
                 case .time, .success, .failures, .failRate: sortAscending = false
                 }
             }
         }

         var body: some View {
             GeometryReader { geometry in
                 let totalFixedWidth = (statusDotWidth + timeWidth + successWidth + failuresWidth + failRateWidth) * scale
                 let totalSpacing = spacing * 5 * scale
                 let targetWidth = max(80 * scale, geometry.size.width - totalFixedWidth - totalSpacing)
                 HStack(spacing: spacing * scale) {
                     Text(" ").frame(width: statusDotWidth * scale, alignment: .center)
                     HeaderButton(title: SortColumn.targetValue.rawValue, column: .targetValue, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .targetValue) }
                         .frame(width: targetWidth, alignment: .leading)
                     HeaderButton(title: SortColumn.time.rawValue, column: .time, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .time) }
                         .frame(width: timeWidth * scale, alignment: .center)
                     HeaderButton(title: SortColumn.success.rawValue, column: .success, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .success) }
                         .frame(width: successWidth * scale, alignment: .center)
                     HeaderButton(title: SortColumn.failures.rawValue, column: .failures, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .failures) }
                         .frame(width: failuresWidth * scale, alignment: .center)
                     HeaderButton(title: SortColumn.failRate.rawValue, column: .failRate, currentSortColumn: sortColumn, currentSortAscending: sortAscending) { setSort(to: .failRate) }
                         .frame(width: failRateWidth * scale, alignment: .center)
                     Spacer(minLength: 0)
                 }
             }
             .font(.system(size: baseFontSize * scale).weight(.semibold)).foregroundColor(.secondary)
             .frame(height: (baseFontSize + 8) * scale)
             .buttonStyle(.borderless).contentShape(Rectangle())
         }
     }

    struct HeaderButton: View {
        @Environment(\.listScale) var scale: CGFloat
        let title: String; let column: SortColumn
        let currentSortColumn: SortColumn?; let currentSortAscending: Bool
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                HStack(spacing: 4 * scale) {
                    Text(title)
                    if currentSortColumn == column { Image(systemName: currentSortAscending ? "arrow.up" : "arrow.down").font(.system(size: 8 * scale)) }
                }
            }
        }
    }

    struct ResultRowView: View {
        @Environment(\.listScale) var scale: CGFloat
        @ObservedObject var result: PingResult
        private let statusDotWidth: CGFloat = 15; private let timeWidth: CGFloat = 140
        private let successWidth: CGFloat = 75; private let failuresWidth: CGFloat = 75
        private let failRateWidth: CGFloat = 85; private let spacing: CGFloat = 8
        private let baseFontSize: CGFloat = 12
        private var statusColor: Color {
            switch result.responseTime.lowercased() {
            case "pending", "pinging...", "paused", "stopped", "cleared", "cancelled": return .orange
            default: return result.isSuccessful ? .green : .red
            }
        }
        var body: some View {
            GeometryReader { geometry in
                 let totalFixedWidth = (statusDotWidth + timeWidth + successWidth + failuresWidth + failRateWidth) * scale
                 let totalSpacing = spacing * 5 * scale
                 let targetWidth = max(80 * scale, geometry.size.width - totalFixedWidth - totalSpacing)
                HStack(spacing: spacing * scale) {
                    Circle().fill(statusColor).frame(width: 10 * scale, height: 10 * scale).frame(width: statusDotWidth * scale, alignment: .center)
                    Text(result.displayName).frame(width: targetWidth, alignment: .leading).lineLimit(1).truncationMode(.tail).foregroundColor(result.isSuccessful ? .green : (statusColor == .red ? .red : .primary))
                    Text(result.responseTime).frame(width: timeWidth * scale, alignment: .center).foregroundColor(result.isSuccessful ? .primary : .secondary).lineLimit(1)
                    Text("\(result.successCount)").fontWeight(.bold).frame(width: successWidth * scale, alignment: .center).foregroundColor(result.isSuccessful ? .green : .primary)
                    Text("\(result.failureCount)").fontWeight(.bold).frame(width: failuresWidth * scale, alignment: .center).foregroundColor(result.failureCount > 0 ? .red : .primary)
                    Text(String(format: "%.1f%%", result.failureRate)).frame(width: failRateWidth * scale, alignment: .center)
                    Spacer(minLength: 0)
                }
                .font(.system(size: baseFontSize * scale, design: .monospaced))
            }
            .frame(height: (baseFontSize + 8) * scale)
        }
    }

    // Helper View for Status Text (Unchanged)
    struct StatusTextView: View {
        let label: String, value: String; var color: Color? = nil; var weight: Font.Weight = .regular
        var body: some View { Text(label + " ") + Text(value).fontWeight(weight).foregroundColor(color) }
    }

} // End of PingResultsView struct


// MARK: - Extension for Sorting Helpers (Unchanged)
extension PingResultsView {
    private func parseTimeValue(_ timeString: String) -> Double {
        switch timeString.lowercased() {
        case "timeout", "failed", "error", "no output", "host unknown", "invalid target", "invalid ip", "network down", "no route", "cancelled": return Double.infinity
        case "pending", "pinging...", "paused", "stopped", "cleared": return Double.infinity - 1
        default: let c = timeString.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted); let n = c.first(where: { !$0.isEmpty && Double($0) != nil }) ?? ""; return Double(n) ?? Double.infinity
        }
    }
    private func compareResponseTimes(_ time1: String, _ time2: String) -> Bool { return parseTimeValue(time1) < parseTimeValue(time2) }
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

// Helper Environment Key for scaling (Unchanged)
private struct ListScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1.0 }
extension EnvironmentValues {
    var listScale: CGFloat {
        get { self[ListScaleKey.self] }
        set { self[ListScaleKey.self] = newValue }
    }
}

