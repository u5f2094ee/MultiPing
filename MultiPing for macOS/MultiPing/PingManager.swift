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

// MARK: - Custom Timeout Error for clarity (Unchanged)
enum TimeoutError: Error {
    case operationTimedOut
}

// MARK: - Ping Manager Class
class PingManager: ObservableObject {
    // MARK: - Published Properties (Unchanged)
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

    // MARK: - Private Properties (Unchanged)
    private var pingTaskGroup: Task<Void, Never>? = nil
    private var currentTimeout: String = "2000"
    private var currentInterval: String = "10"
    private var currentSize: String = "32"
    private var calculatedMaxJitterNano: Int64 = 1_000_000_000
    private let limiter = PingConcurrencyLimiter(limit: 80) // Concurrency limit

    // MARK: - Initialization (Unchanged)
    init() {
        self.ipInput = UserDefaults.standard.string(forKey: userDefaultsIPKey) ?? ""
        // print("PingManager init") // For debugging
        Task { @MainActor in self.updateTotalCounts() }
    }

    // MARK: - Deinitializer (Unchanged)
    deinit {
        print("PingManager deinit called. Current status: \(pingStatus)")
        // Ensure the main task group is cancelled when PingManager is deallocated.
        // This is a safety net. stopPingTasks should ideally handle this earlier
        // if called from onDisappear or applicationWillTerminate.
        pingTaskGroup?.cancel()
        pingTaskGroup = nil // Ensure it's nilled out
    }

    // MARK: - Action Methods
    // startPingTasks and togglePause remain unchanged
    func startPingTasks(timeout: String, interval: String, size: String) {
        guard !pingStarted else { return }
        let isResuming = (pingStatus == "Paused")
        self.currentTimeout = timeout; self.currentInterval = interval; self.currentSize = size
        pingStarted = true; isPaused = false; pingStatus = "Pinging..."
        let targetCount = results.count
        self.calculatedMaxJitterNano = targetCount > 0 ? (Int64(targetCount) * 14 * 1_000_000) : 3_000_000_000
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
        pingTaskGroup = nil // Explicitly nil before creating new
        pingTaskGroup = Task {
            await runPingLoop()
            if !Task.isCancelled {
                 await MainActor.run {
                    if self.pingStarted && !self.isPaused {
                        self.pingStarted = false
                        self.pingStatus = "Completed"
                    }
                    if self.pingStatus != "Pinging..." {
                        for result in self.results where result.responseTime.lowercased() == "pinging..." {
                            result.responseTime = self.pingStatus
                            if ["Completed", "Stopped", "Cleared", "Cancelled"].contains(self.pingStatus) {
                                result.isSuccessful = false
                            }
                        }
                    }
                    self.updateTotalCounts()
                }
            }
        }
    }

    func togglePause() {
        guard (pingStatus == "Pinging..." && !isPaused) || (pingStatus == "Paused" && isPaused) else { return }
        if !isPaused {
            isPaused = true
            pingStarted = false // Important: mark as not "pingStarted" when paused.
            pingStatus = "Paused"
            pingTaskGroup?.cancel()
            pingTaskGroup = nil
            Task { [weak self] in
                await MainActor.run {
                    guard let self = self else { return }
                    for result in self.results where result.responseTime.lowercased() == "pinging..." {
                        result.responseTime = "Paused"
                    }
                    self.updateTotalCounts()
                }
            }
        } else {
            // isPaused was true, so we are resuming
            // isPaused will be set to false by startPingTasks
            startPingTasks(timeout: currentTimeout, interval: currentInterval, size: currentSize)
        }
    }

    // MARK: - stopPingTasks (Unchanged from previous version in this artifact)
    func stopPingTasks(clearResults: Bool) {
        // print("stopPingTasks called from PingManager, clearResults: \(clearResults)")
        
        let previousStatus = self.pingStatus // Capture status before changes
        let wasEffectivelyRunning = pingStarted || previousStatus == "Pinging..." || previousStatus == "Paused"

        // 1. Immediately cancel any ongoing ping task group.
        // This is crucial to stop new Process objects from being created or managed.
        pingTaskGroup?.cancel()
        pingTaskGroup = nil

        // 2. Update state flags synchronously.
        pingStarted = false
        isPaused = false
        
        let newFinalStatus = clearResults ? "Cleared" : "Stopped"

        // 3. Asynchronously update UI-related properties and individual results on the main actor.
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.pingStatus = newFinalStatus

            if wasEffectivelyRunning || clearResults {
                for result in self.results {
                    let currentItemStatus = result.responseTime.lowercased()
                    
                    if clearResults ||
                       ["pinging...", "paused", "pending"].contains(currentItemStatus) ||
                       (newFinalStatus == "Stopped" && wasEffectivelyRunning) {
                        result.responseTime = newFinalStatus
                        result.isSuccessful = false
                    }

                    if clearResults {
                        result.resetStats(initialStatus: "Cleared")
                    }
                }
            }
            self.updateTotalCounts()
        }
    }


    // MARK: - Internal Pinging Logic (Unchanged from user's provided code)
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

                    roundGroup.addTask { [weak self] in
                        guard let self = self else { return }

                        let targetID = currentTargetResult.id
                        await self.limiter.acquireSlot()
                        defer { Task { await self.limiter.releaseSlot() } }

                        guard !Task.isCancelled && self.pingStarted && !self.isPaused else { return }
                        
                        let response = await self.performPing(for: currentTargetResult, timeout: self.currentTimeout, size: self.currentSize)
                        
                        guard !Task.isCancelled && self.pingStarted && !self.isPaused else { return }

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

            do {
                try await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000.0))
            } catch {
                break
            }
        }
    }

    // MARK: - Timeout Helper (Unchanged from user's provided code)
    private func withTimeout<T: Sendable>(
        nanoseconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: nanoseconds)
                throw TimeoutError.operationTimedOut
            }
            guard let result = try await group.next() else {
                throw NSError(domain: "PingManagerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task group completed without a result."])
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Ping Execution and Parsing (MODIFIED with Task.yield)
    private func performPing(for targetResult: PingResult, timeout: String, size: String) async -> String {
        guard !targetResult.targetValue.isEmpty else { return "Invalid Target" }

        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let fileHandleForReading = pipe.fileHandleForReading

        let timeoutMs = Int(timeout) ?? 2000
        let packetSize = max(0, Int(size) ?? 32)

        switch targetResult.targetType {
        case .ipv6:
            process.executableURL = URL(fileURLWithPath: "/sbin/ping6")
            process.arguments = ["-c", "1", "-s", String(packetSize), targetResult.targetValue]
        case .ipv4, .domain, .unknown:
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", String(timeoutMs), "-s", String(packetSize), targetResult.targetValue]
        }

        var rawOutputString: String?
        let swiftTimeoutNano = UInt64(max(1, timeoutMs)) * 1_000_000 + 500_000_000 // 0.5s buffer

        defer {
            try? fileHandleForReading.close()
        }

        do {
            return try await withTimeout(nanoseconds: swiftTimeoutNano) {
                if Task.isCancelled { // Check before running
                    return "Cancelled"
                }

                try process.run()

                async let outputData: Data? = try? fileHandleForReading.readToEnd()
                await process.waitUntilExit()

                if Task.isCancelled { // Check after waiting
                    if process.isRunning {
                        process.terminate()
                        await Task.yield() // ADDED: Allow termination to propagate
                    }
                    return "Cancelled"
                }
                
                let data = await outputData
                rawOutputString = data.flatMap { String(data: $0, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) }

                guard let finalOutput = rawOutputString, !finalOutput.isEmpty else {
                    return process.terminationStatus == 0 ? "No output" : "Failed"
                }

                if process.terminationStatus != 0 {
                    // Even if status != 0, output might contain time if -W (timeout for ping command) was hit
                    if finalOutput.contains("time=") || finalOutput.contains("bytes from") {
                        return self.parsePingOutput(finalOutput, for: targetResult.targetType)
                    }
                    return self.parsePingError(finalOutput)
                }
                return self.parsePingOutput(finalOutput, for: targetResult.targetType)
            }
        } catch is TimeoutError {
            if process.isRunning {
                process.terminate()
                await Task.yield() // ADDED: Allow termination to propagate
            }
            return "Timeout"
        } catch is CancellationError {
            if process.isRunning {
                process.terminate()
                await Task.yield() // ADDED: Allow termination to propagate
            }
            return "Cancelled"
        } catch {
            // General error catch
            if Task.isCancelled { // Check if the error was due to cancellation
                 if process.isRunning {
                    process.terminate()
                    await Task.yield() // ADDED: Allow termination to propagate
                 }
                 return "Cancelled"
            }
            // If not a cancellation error, but process is still running (unlikely but possible)
            if process.isRunning {
                process.terminate()
                await Task.yield() // ADDED: Allow termination to propagate
            }
            
            // Try to parse output if available, otherwise return generic error
            if let output = rawOutputString, !output.isEmpty {
                return self.parsePingError(output)
            }
            return "Error"
        }
    }

    // MARK: - Parsing Methods (Unchanged)
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

     private func parsePingError(_ output: String) -> String {
         let lowerOutput = output.lowercased()
         if lowerOutput.contains("timeout") || lowerOutput.contains("request timeout") { return "Timeout" }
         else if lowerOutput.contains("cannot resolve") || lowerOutput.contains("unknown host") || lowerOutput.contains("name or service not known") { return "Host unknown" }
         else if lowerOutput.contains("network is unreachable") { return "Network down" }
         else if lowerOutput.contains("no route to host") { return "No route" }
         else if lowerOutput.contains("host unreachable") { return "Host unreachable" }
         else if lowerOutput.contains("invalid argument") && lowerOutput.contains("ping") { return "Invalid Target" }
         else if lowerOutput.contains("permission denied") { return "Permission denied"}
         return "Failed" // Default to "Failed" if no specific error pattern matches
     }

    // MARK: - Update Counts (Unchanged)
    @MainActor private func updateTotalCounts() {
        reachableCount = results.filter { $0.isSuccessful && !["pinging...", "pending", "paused", "stopped", "cleared", "cancelled"].contains($0.responseTime.lowercased()) }.count
        failedCount = results.filter { !$0.isSuccessful && !["pinging...", "pending", "paused", "stopped", "cleared", "cancelled"].contains($0.responseTime.lowercased()) }.count
    }
}
