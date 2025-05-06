import Foundation
import Combine
import SwiftUI // Needed for Process

// MARK: - Concurrency Limiter Actor
/// An actor to limit the number of concurrent ping operations.
actor PingConcurrencyLimiter {
    private let limit: Int
    private var currentCount: Int = 0

    /// Initializes the limiter with a maximum concurrency count.
    init(limit: Int) {
        self.limit = max(1, limit) // Ensure limit is at least 1
    }

    /// Asynchronously acquires a slot for executing a ping.
    /// Suspends if the limit is reached until a slot becomes available.
    func acquireSlot() async {
        while true {
            if currentCount < limit {
                currentCount += 1
                return // Slot acquired
            }
            await Task.yield() // Suspend and check again later
            // Consider adding Task.checkCancellation() here if needed
        }
    }

    /// Releases a previously acquired slot.
    func releaseSlot() {
        if currentCount > 0 {
            currentCount -= 1
        } else {
            print("Warning: Attempted to release a slot when count was already zero.")
        }
    }
}


// MARK: - Ping Manager Class
class PingManager: ObservableObject {

    private let userDefaultsIPKey = "lastIPInput"
    @Published var ipInput: String { didSet { UserDefaults.standard.set(ipInput, forKey: userDefaultsIPKey) } }
    @Published var results: [PingResult] = [] { didSet { Task { @MainActor in self.updateTotalCounts() } } }
    @Published var pingStarted = false
    @Published var isPaused = false
    @Published var pingStatus: String = "Stopped"
    @Published var reachableCount: Int = 0
    @Published var failedCount: Int = 0

    private var pingTaskGroup: Task<Void, Never>? = nil
    private var currentTimeout: String = "1000"
    private var currentInterval: String = "5"
    private var currentSize: String = "56"
    private var calculatedMaxJitterNano: Int64 = 1_000_000_000 // Default to 1000ms
    private let limiter = PingConcurrencyLimiter(limit: 50) // Limit to 50 concurrent pings

    init() {
        self.ipInput = UserDefaults.standard.string(forKey: userDefaultsIPKey) ?? ""
    }

    // MARK: - Action Methods

    func startPingTasks(timeout: String, interval: String, size: String) {
        guard !pingStarted || isPaused else { return }
        self.currentTimeout = timeout; self.currentInterval = interval; self.currentSize = size
        isPaused = false; pingStarted = true; pingStatus = "Pinging..."

        let ipCount = results.count
        self.calculatedMaxJitterNano = ipCount > 0 ? (Int64(ipCount) * 18 * 1_000_000) : 1_000_000_000 // count * 18ms

        Task { await MainActor.run { for result in results { result.resetStats(initialStatus: "Pinging...") }; self.updateTotalCounts() } }
        pingTaskGroup?.cancel()
        pingTaskGroup = Task {
            await runPingLoop()
            await MainActor.run { // Post-loop cleanup
                 if pingStarted && !isPaused { pingStarted = false; pingStatus = "Completed"; }
                 for result in results where result.responseTime == "Pinging..." { result.responseTime = pingStatus; result.isSuccessful = false }
                 self.updateTotalCounts()
            }
        }
    }

    func togglePause() {
        guard pingStarted else { return }
        let intendedPauseState = !isPaused
        if intendedPauseState { pingTaskGroup?.cancel(); pingTaskGroup = nil }
        isPaused = intendedPauseState; pingStatus = isPaused ? "Paused" : "Pinging..."
        if isPaused {
            Task { await MainActor.run { for result in results where result.responseTime == "Pinging..." { result.responseTime = "Paused" }; self.updateTotalCounts() } }
        } else { // Resuming
             pingStarted = true
             pingTaskGroup?.cancel()
             pingTaskGroup = Task {
                 await MainActor.run { for result in results where result.responseTime == "Paused" { result.responseTime = "Pinging..." } }
                 await runPingLoop()
                 await MainActor.run { // Post-loop cleanup
                      if pingStarted && !isPaused { pingStarted = false; pingStatus = "Completed" }
                      if !isPaused { for result in results where result.responseTime == "Pinging..." { result.responseTime = pingStatus; result.isSuccessful = false } }
                      self.updateTotalCounts()
                 }
             }
        }
    }

    func stopPingTasks(clearResults: Bool) {
        let wasStarted = pingStarted
        pingStarted = false; isPaused = false
        let finalStatus = clearResults ? "Cleared" : "Stopped"
        pingStatus = finalStatus
        pingTaskGroup?.cancel(); pingTaskGroup = nil
        if wasStarted || clearResults {
            Task { await MainActor.run { // Update results on main thread
                for result in results {
                    let currentStatus = result.responseTime
                    if clearResults || ["pinging...", "paused", "pending"].contains(currentStatus.lowercased()) {
                        result.responseTime = finalStatus; result.isSuccessful = false
                    }
                    if clearResults { result.resetStats(initialStatus: "Cleared") }
                }
                 pingStatus = finalStatus; self.updateTotalCounts()
            }}
        }
    }


    // MARK: - Internal Pinging Logic (Corrected Slot Release)

    private func runPingLoop() async {
        let minStaggerDelay: UInt64 =  1_000_000 // 1 ms
        let maxStaggerDelay: UInt64 = 40_000_000 // 40 ms
        let minIntervalJitter: Int64 = -calculatedMaxJitterNano / 2
        let maxIntervalJitter: Int64 =  calculatedMaxJitterNano

        await withTaskGroup(of: Void.self) { group in
            for resultObject in results {
                guard !Task.isCancelled && pingStarted && !isPaused else { break }
                guard results.contains(where: { $0.id == resultObject.id }) else { continue }

                // Stagger Start Delay
                do {
                    let randomDelay = UInt64.random(in: minStaggerDelay...maxStaggerDelay)
                    try await Task.sleep(nanoseconds: randomDelay)
                } catch { break }

                guard !Task.isCancelled && pingStarted && !isPaused else { break }

                group.addTask {
                    let ip = resultObject.ip
                    while !Task.isCancelled && self.pingStarted && !self.isPaused {

                        // --- Acquire Concurrency Slot ---
                        await self.limiter.acquireSlot()

                        // --- MODIFIED: Explicit Slot Release ---
                        var slotReleased = false // Flag to ensure release happens only once
                        let releaseSlotTask = Task { // Create task to release slot later
                            await self.limiter.releaseSlot()
                            slotReleased = true
                        }
                        // --- END MODIFIED ---

                        // Check cancellation *after* acquiring slot
                        guard !Task.isCancelled && self.pingStarted && !self.isPaused else {
                            // If cancelled here, ensure the acquired slot is released
                            if !slotReleased { releaseSlotTask.cancel(); Task { await self.limiter.releaseSlot() } }
                            break
                        }

                        // --- Execute Ping ---
                        let currentResponseTime = await self.ping(ip: ip, timeout: self.currentTimeout, size: self.currentSize)
                        let wasCancelledDuringPing = Task.isCancelled

                        // --- Release Slot IMMEDIATELY after ping attempt finishes ---
                        // Cancel the scheduled release task and release immediately
                        if !slotReleased {
                            releaseSlotTask.cancel() // Cancel the deferred release
                            await self.limiter.releaseSlot() // Release now
                            slotReleased = true // Mark as released
                        }
                        // --- END MODIFIED ---


                        // --- Update UI (only if not cancelled/paused/stopped AFTER ping) ---
                        guard !wasCancelledDuringPing && self.pingStarted && !self.isPaused else { break } // Break loop if state changed during ping

                        let currentSuccess = ["timeout", "error", "no output", "failed", "host unknown", "invalid ip", "network down", "cancelled", "no route"].allSatisfy { !currentResponseTime.lowercased().contains($0) }

                        await MainActor.run {
                            guard self.pingStarted, !self.isPaused else { return }
                            resultObject.responseTime = currentResponseTime
                            resultObject.isSuccessful = currentSuccess
                            if currentSuccess { resultObject.successCount += 1 }
                            else { if !["paused", "stopped", "cancelled", "pinging...", "pending", "cleared"].contains(currentResponseTime.lowercased()) { resultObject.failureCount += 1 } }
                            let totalPings = resultObject.successCount + resultObject.failureCount
                            resultObject.failureRate = totalPings > 0 ? (Double(resultObject.failureCount) / Double(totalPings)) * 100.0 : 0.0
                            self.updateTotalCounts()
                        }

                        // --- Interval Sleep with Jitter (only if not cancelled/paused/stopped) ---
                        guard !Task.isCancelled && self.pingStarted && !self.isPaused else { break }

                        do {
                            let baseIntervalSeconds = Int64(self.currentInterval) ?? 5
                            let baseIntervalNano = UInt64(max(1, baseIntervalSeconds) * 1_000_000_000)
                            let randomJitterNano = Int64.random(in: minIntervalJitter...maxIntervalJitter)
                            let potentialTotalNano = Int64(baseIntervalNano) + randomJitterNano
                            let totalSleepNano = UInt64(max(1, potentialTotalNano))
                            try await Task.sleep(nanoseconds: totalSleepNano)
                        } catch { break } // Exit loop if sleep is cancelled
                    } // End while loop for this IP
                } // End group.addTask
            } // End for loop iterating through results
        } // End withTaskGroup
    }


    // MARK: - Ping Execution and Parsing Helpers (Unchanged)

    private func ping(ip: String, timeout: String, size: String) async -> String {
        guard !ip.isEmpty, isValidIPAddress(ip) else { return "Invalid IP" }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        let timeoutMs = Int(timeout) ?? 1000
        let packetSize = max(0, Int(size) ?? 56)
        task.arguments = ["-c", "1", "-W", String(timeoutMs), "-s", String(packetSize), ip]

        let pipe = Pipe()
        task.standardOutput = pipe; task.standardError = pipe
        var processOutput: String? = nil

        do {
            if Task.isCancelled { return "Cancelled" }
            try task.run()

            async let waitTask: Void = task.waitUntilExit()
            async let readDataTask: Data? = try? pipe.fileHandleForReading.readToEnd()
            let effectiveTimeoutMs = max(1, timeoutMs)
            async let timeoutTask: Void = Task.sleep(nanoseconds: UInt64(effectiveTimeoutMs + 500) * 1_000_000)

            _ = try await (readDataTask, waitTask, timeoutTask) // Await concurrently

             if Task.isCancelled { if task.isRunning { task.terminate() }; return "Cancelled" }

            if task.isRunning { task.terminate(); return "Timeout" }

            guard let data = await readDataTask, let output = String(data: data, encoding: .utf8) else {
                return task.terminationStatus == 0 ? "No output" : "Failed"
            }
            processOutput = output

            if task.terminationStatus != 0 && !output.contains("time=") {
                return parsePingError(output)
            }
            return parsePingOutput(output)
        } catch {
             if Task.isCancelled { return "Cancelled" }
             if let output = processOutput { return parsePingError(output) }
             return "Error"
        }
    }

    private func isValidIPAddress(_ ipString: String) -> Bool {
         let parts = ipString.split(separator: ".")
         guard parts.count == 4 else { return false }
         return parts.allSatisfy { part in guard let number = Int(part) else { return false }; return number >= 0 && number <= 255 }
     }

    private func parsePingOutput(_ output: String) -> String {
         let regex = try? NSRegularExpression(pattern: #"time=(\d+(\.\d+)?)\s*ms"#, options: [])
         if let match = regex?.firstMatch(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count)),
            let range = Range(match.range(at: 1), in: output) {
             return "\(String(output[range])) ms"
         }
         else { return "Failed" }
    }

     private func parsePingError(_ output: String) -> String {
         if output.contains("timeout") || output.contains("Request timeout") { return "Timeout" }
         else if output.contains("cannot resolve") || output.contains("Unknown host") { return "Host unknown" }
         else if output.contains("Network is unreachable") { return "Network down" }
         else if output.contains("sendto: No route to host") { return "No route" }
         else { return "Failed" }
     }


    // MARK: - Function to update total counts (Unchanged)

    private func updateTotalCounts() {
        reachableCount = results.filter { $0.isSuccessful && !$0.responseTime.lowercased().contains("pinging") && !$0.responseTime.lowercased().contains("pending") }.count
        failedCount = results.filter { !$0.isSuccessful && !$0.responseTime.lowercased().contains("pinging") && !$0.responseTime.lowercased().contains("pending") && !$0.responseTime.lowercased().contains("paused") && !$0.responseTime.lowercased().contains("stopped") && !$0.responseTime.lowercased().contains("cleared") && !$0.responseTime.lowercased().contains("cancelled") }.count
    }

} // End Class PingManager

