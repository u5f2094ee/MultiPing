import Foundation
import Combine
import SwiftUI // Needed for Process

// MARK: - Concurrency Limiter Actor (Unchanged)
actor PingConcurrencyLimiter {
    private let limit: Int
    private var currentCount: Int = 0

    init(limit: Int) {
        self.limit = max(1, limit) // Ensure limit is at least 1
    }

    func acquireSlot() async {
        while true {
            if currentCount < limit {
                currentCount += 1
                return // Slot acquired
            }
            await Task.yield() // Yield if limit reached
        }
    }

    func releaseSlot() {
        if currentCount > 0 {
            currentCount -= 1
        }
    }
}

// MARK: - Ping Manager Class
class PingManager: ObservableObject {
    // MARK: - Published Properties
    private let userDefaultsIPKey = "lastIPInput"
    @Published var ipInput: String {
        didSet { UserDefaults.standard.set(ipInput, forKey: userDefaultsIPKey) }
    }
    @Published var results: [PingResult] = [] {
        didSet { Task { @MainActor in self.updateTotalCounts() } }
    }
    @Published var pingStarted = false
    @Published var isPaused = false
    @Published var pingStatus: String = "Stopped"
    @Published var reachableCount: Int = 0
    @Published var failedCount: Int = 0

    // MARK: - Private Properties
    private var pingTaskGroup: Task<Void, Never>? = nil
    private var currentTimeout: String = "2000"
    private var currentInterval: String = "10"
    private var currentSize: String = "32"
    private var calculatedMaxJitterNano: Int64 = 1_000_000_000
    private let limiter = PingConcurrencyLimiter(limit: 80) // Concurrency limit

    // MARK: - Initialization
    init() {
        self.ipInput = UserDefaults.standard.string(forKey: userDefaultsIPKey) ?? ""
        Task { @MainActor in self.updateTotalCounts() }
    }

    // MARK: - Action Methods (Start, Pause/Resume, Stop - Unchanged from v3 fix)

    /// Starts the pinging process or resumes from pause.
    /// Ensures stats are reset only on a fresh start, not on resume.
    func startPingTasks(timeout: String, interval: String, size: String) {
        // Guard: Prevent starting if already started.
        // Allows resuming because pingStarted is set to false when paused.
        guard !pingStarted else { return }
        let isResuming = (pingStatus == "Paused")
        self.currentTimeout = timeout; self.currentInterval = interval; self.currentSize = size
        pingStarted = true; isPaused = false; pingStatus = "Pinging..."
        let targetCount = results.count
        self.calculatedMaxJitterNano = targetCount > 0 ? (Int64(targetCount) * 14 * 1_000_000) : 1_000_000_000
        if !isResuming {
            Task {
                await MainActor.run {
                    for result in results { result.resetStats(initialStatus: "Pinging...") }
                    self.updateTotalCounts()
                }
            }
        } else {
             Task {
                 await MainActor.run {
                     for result in results where result.responseTime.lowercased() == "paused" {
                         result.responseTime = "Pinging..."
                     }
                 }
             }
        }
        pingTaskGroup?.cancel()
        pingTaskGroup = Task {
            await runPingLoop()
            // --- Post-Loop Cleanup ---
            await MainActor.run {
                if Task.isCancelled { /* Status set by stop/pause */ }
                else if self.pingStarted && !self.isPaused {
                    self.pingStarted = false; self.pingStatus = "Completed"
                }
                if self.pingStatus != "Pinging..." {
                    for result in results where result.responseTime.lowercased() == "pinging..." {
                        result.responseTime = self.pingStatus
                        if ["Completed", "Stopped", "Cleared", "Cancelled"].contains(self.pingStatus) {
                            result.isSuccessful = false
                        }
                    }
                }
                self.updateTotalCounts()
            }
            // --- End Post-Loop Cleanup ---
        }
    }

    /// Toggles the paused state of the pinging process.
    func togglePause() {
        guard (pingStatus == "Pinging..." && !isPaused) || (pingStatus == "Paused" && isPaused) else { return }
        if !isPaused {
            // --- Pausing ---
            isPaused = true; pingStarted = false // Set pingStarted false
            pingStatus = "Paused"; pingTaskGroup?.cancel(); pingTaskGroup = nil
            Task {
                await MainActor.run {
                    for result in results where result.responseTime.lowercased() == "pinging..." {
                        result.responseTime = "Paused"
                    }
                    self.updateTotalCounts()
                }
            }
        } else {
            // --- Resuming ---
            isPaused = false // Set isPaused false *before* calling start
            startPingTasks(timeout: currentTimeout, interval: currentInterval, size: currentSize)
        }
    }

    /// Stops the pinging process.
    func stopPingTasks(clearResults: Bool) {
        let wasStartedOrPaused = pingStarted || self.pingStatus == "Pinging..." || self.pingStatus == "Paused"
        pingStarted = false; isPaused = false
        let finalStatus = clearResults ? "Cleared" : "Stopped"
        Task { @MainActor in self.pingStatus = finalStatus }
        pingTaskGroup?.cancel(); pingTaskGroup = nil
        if wasStartedOrPaused || clearResults {
            Task {
                await MainActor.run {
                    for result in results {
                        let currentStatus = result.responseTime.lowercased()
                        if clearResults || ["pinging...", "paused", "pending"].contains(currentStatus) {
                            result.responseTime = finalStatus; result.isSuccessful = false
                        }
                        if clearResults { result.resetStats(initialStatus: "Cleared") }
                    }
                    self.updateTotalCounts()
                }
            }
        }
    }

    // MARK: - Internal Pinging Logic (Round-Based - Unchanged from v3 fix)

    /// Runs the ping loop in synchronized rounds.
    private func runPingLoop() async {
        let minStaggerDelay: UInt64 = 1_000_000, maxStaggerDelay: UInt64 = 30_000_000
        let minIntervalJitter: Int64 = -calculatedMaxJitterNano / 2, maxIntervalJitter: Int64 = calculatedMaxJitterNano
        while !Task.isCancelled && pingStarted && !isPaused {
            let roundStartTime = Date()
            await withTaskGroup(of: Void.self) { roundGroup in
                for currentTargetResult in results {
                    guard !Task.isCancelled && pingStarted && !isPaused else { break }
                    guard results.contains(where: { $0.id == currentTargetResult.id }) else { continue }
                    do { try await Task.sleep(nanoseconds: UInt64.random(in: minStaggerDelay...maxStaggerDelay)) }
                    catch { break }
                    guard !Task.isCancelled && pingStarted && !isPaused else { break }
                    roundGroup.addTask {
                        let targetID = currentTargetResult.id
                        await self.limiter.acquireSlot(); var slotReleased = false
                        let releaseSlotTask = Task { await self.limiter.releaseSlot(); slotReleased = true }
                        guard !Task.isCancelled && self.pingStarted && !self.isPaused else {
                            if !slotReleased { releaseSlotTask.cancel(); Task { await self.limiter.releaseSlot() } }
                            return
                        }
                        // Call the updated performPing function
                        let response = await self.performPing(for: currentTargetResult, timeout: self.currentTimeout, size: self.currentSize)
                        let wasCancelledDuringPing = Task.isCancelled
                        if !slotReleased { releaseSlotTask.cancel(); await self.limiter.releaseSlot() }
                        guard !wasCancelledDuringPing && self.pingStarted && !self.isPaused else { return }
                        let currentSuccess = !["timeout", "error", "no output", "failed", "host unknown", "invalid target", "network down", "cancelled", "no route"].contains { response.lowercased().contains($0) } && !response.isEmpty
                        await MainActor.run {
                            guard self.pingStarted, !self.isPaused, let resultToUpdate = self.results.first(where: { $0.id == targetID }) else { return }
                            resultToUpdate.responseTime = response; resultToUpdate.isSuccessful = currentSuccess
                            if currentSuccess { resultToUpdate.successCount += 1 }
                            else { if !["paused", "stopped", "cancelled", "pinging...", "pending", "cleared"].contains(response.lowercased()) { resultToUpdate.failureCount += 1 } }
                            let totalPings = resultToUpdate.successCount + resultToUpdate.failureCount
                            resultToUpdate.failureRate = totalPings > 0 ? (Double(resultToUpdate.failureCount) / Double(totalPings)) * 100.0 : 0.0
                            self.updateTotalCounts()
                        }
                    }
                }
                await roundGroup.waitForAll()
            }
            guard !Task.isCancelled && pingStarted && !isPaused else { break }
            let roundEndTime = Date(); let roundDuration = roundEndTime.timeIntervalSince(roundStartTime)
            let baseIntervalSeconds = TimeInterval(Int(self.currentInterval) ?? 5)
            let remainingWaitTime = max(0.01, baseIntervalSeconds - roundDuration)
            let randomJitterNano = Int64.random(in: minIntervalJitter...maxIntervalJitter)
            let jitterSeconds = TimeInterval(randomJitterNano) / 1_000_000_000.0
            let sleepDuration = max(0.01, remainingWaitTime + jitterSeconds)
            do { try await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000.0)) }
            catch { break }
        }
    }

    // MARK: - Ping Execution and Parsing (Updated)

    /// Executes the `ping` or `ping6` command for a single target.
    /// - Parameters:
    ///   - targetResult: The PingResult object containing target info.
    ///   - timeout: Timeout for the ping in milliseconds (used for Swift concurrency timeout).
    ///   - size: Packet size in bytes.
    /// - Returns: A string representing the result (e.g., "64.5 ms", "Timeout", "Failed").
    private func performPing(for targetResult: PingResult, timeout: String, size: String) async -> String {
        guard !targetResult.targetValue.isEmpty else { return "Invalid Target" }
        let task = Process(); let pipe = Pipe(); task.standardOutput = pipe; task.standardError = pipe
        let timeoutMs = Int(timeout) ?? 2000 // Used for Swift timeout monitor
        let packetSize = max(0, Int(size) ?? 32)
        var commandToLog = ""

        // Configure command based on target type
        switch targetResult.targetType {
        case .ipv6:
            task.executableURL = URL(fileURLWithPath: "/sbin/ping6")
            // macOS ping6 arguments:
            // -c 1: Send only one packet
            // -s size: Packet data size (payload)
            // *** REMOVED -W argument for ping6 ***
            task.arguments = ["-c", "1", "-s", String(packetSize), targetResult.targetValue]
            commandToLog = "/sbin/ping6 \(task.arguments?.joined(separator: " ") ?? "")"
        case .ipv4, .domain, .unknown:
            task.executableURL = URL(fileURLWithPath: "/sbin/ping")
            // macOS ping arguments:
            // -c 1: Send only one packet
            // -W waittime: Time to wait for a reply in milliseconds (still used for ping)
            // -s size: Packet data size (payload)
            task.arguments = ["-c", "1", "-W", String(timeoutMs), "-s", String(packetSize), targetResult.targetValue]
            commandToLog = "/sbin/ping \(task.arguments?.joined(separator: " ") ?? "")"
        }
        // print("Executing: \(commandToLog)") // Uncomment for debugging

        var rawOutputString: String? = nil
        do {
            if Task.isCancelled { return "Cancelled" }
            try task.run()
            async let waitTask: Void = task.waitUntilExit()
            async let readDataTask: Data? = try? pipe.fileHandleForReading.readToEnd()
            // Swift Concurrency Timeout Monitor (applies to both ping and ping6)
            // Uses the user-defined timeout + a buffer.
            let swiftTimeoutNano = UInt64(max(1, timeoutMs)) * 1_000_000 + 500_000_000 // ms to ns + 0.5s buffer
            async let timeoutMonitorTask: Void = Task.sleep(nanoseconds: swiftTimeoutNano)

            _ = try await (readDataTask, waitTask, timeoutMonitorTask)

            if Task.isCancelled { if task.isRunning { task.terminate() }; return "Cancelled" }
            // Check if Swift timeout monitor finished before the process exited
            if task.isRunning {
                task.terminate()
                return "Timeout" // Return "Timeout" if Swift timeout triggered
            }
            guard let data = await readDataTask, let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return task.terminationStatus == 0 ? "No output" : "Failed"
            }
            rawOutputString = output
            // print("Raw output for \(targetResult.targetValue): \(output)")
            if task.terminationStatus != 0 {
                 // Check for success indicators even on non-zero exit (e.g., TTL expired)
                if output.contains("time=") || output.contains("bytes from") {
                     return parsePingOutput(output, for: targetResult.targetType)
                }
                return parsePingError(output) // Parse specific error messages
            }
            // Success exit code (0)
            return parsePingOutput(output, for: targetResult.targetType)
        } catch {
            // print("Error running ping for \(targetResult.targetValue): \(error)")
            if Task.isCancelled { return "Cancelled" }
            if let output = rawOutputString, !output.isEmpty { return parsePingError(output) }
            return "Error" // Generic error
        }
    }

    /// Parses successful ping output to extract the response time. (Unchanged)
    private func parsePingOutput(_ output: String, for targetType: TargetType) -> String {
        let regexPattern: String = #"time(?:<|=)(\d+(\.\d+)?)\s*ms"#
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: [])
            if let match = regex.firstMatch(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count)) {
                if let range = Range(match.range(at: 1), in: output) {
                    let timeValue = String(output[range]); return output.contains("time<") ? "< \(timeValue) ms" : "\(timeValue) ms"
                }
            }
        } catch { /* print("Regex error: \(error)") */ }
        if output.contains("bytes from") { return "Success (no time)" }; return "Failed"
    }

    /// Parses error output from the ping command. (Unchanged)
     private func parsePingError(_ output: String) -> String {
         let lowerOutput = output.lowercased()
         if lowerOutput.contains("timeout") || lowerOutput.contains("request timeout") { return "Timeout" }
         else if lowerOutput.contains("cannot resolve") || lowerOutput.contains("unknown host") || lowerOutput.contains("name or service not known") { return "Host unknown" }
         else if lowerOutput.contains("network is unreachable") { return "Network down" }
         else if lowerOutput.contains("no route to host") { return "No route" }
         else if lowerOutput.contains("host unreachable") { return "Host unreachable" }
         else if lowerOutput.contains("invalid argument") && lowerOutput.contains("ping") { return "Invalid Target" }
         else if lowerOutput.contains("permission denied") { return "Permission denied"}
         return "Failed"
     }

    /// Updates the `reachableCount` and `failedCount`. (Unchanged)
    @MainActor private func updateTotalCounts() {
        reachableCount = results.filter { $0.isSuccessful && !["pinging...", "pending", "paused", "stopped", "cleared", "cancelled"].contains($0.responseTime.lowercased()) }.count
        failedCount = results.filter { !$0.isSuccessful && !["pinging...", "pending", "paused", "stopped", "cleared", "cancelled"].contains($0.responseTime.lowercased()) }.count
    }
}

