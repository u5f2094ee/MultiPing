import SwiftUI

struct PingResultsView: View {
    // ObservedObject to react to changes in PingManager
    @ObservedObject var manager: PingManager
    // Settings passed from the previous view
    var timeout: String
    var interval: String
    var size: String
    // Binding to update the status display
    @Binding var pingStatus: String

    // State variables to control the pinging process
    @State private var stopPinging = false
    @State private var isPaused = false
    // State variable to hold the TaskGroup reference for cancellation
    @State private var pingTaskGroup: Task<Void, Never>? = nil


    var body: some View {
        // Main container VStack
        VStack(spacing: 0) { // Use spacing: 0 to control padding manually

            // --- Top Control Area ---
            VStack(spacing: 10) {
                // Status Information Row
                HStack {
                    Text("Timeout: \(timeout) ms")
                    Spacer() // Pushes elements apart
                    Text("Interval: \(interval) s")
                    Spacer()
                    Text("Size: \(size) B") // Use B for Bytes
                    Spacer()
                    Text("Status: \(pingStatus)")
                        .fontWeight(.medium) // Make status slightly bolder
                }
                .font(.caption) // Use caption font for less emphasis
                .padding(.horizontal)
                .padding(.top) // Add padding above the status info

                // Action Buttons Row
                HStack {
                    Button("Start Ping") {
                        // Logic to start pinging
                        if !manager.pingStarted {
                            stopPinging = false
                            isPaused = false
                            manager.pingStarted = true
                            pingStatus = "Pinging..." // More concise status
                            // Start the pinging task
                            pingTaskGroup = Task {
                               await startPing()
                                // Reset status when done (if not stopped explicitly)
                                if !stopPinging && !Task.isCancelled {
                                    await MainActor.run {
                                        manager.pingStarted = false
                                        pingStatus = isPaused ? "Paused" : "Completed"
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.bordered) // Use bordered style for less prominence than Okay
                    .tint(.green) // Add color hint
                    .disabled(manager.pingStarted && !isPaused) // Disable if running

                    Button(isPaused ? "Resume" : "Pause") { // Shorter labels
                        if manager.pingStarted {
                            isPaused.toggle() // Toggle pause state
                            if isPaused {
                                pingStatus = "Paused"
                                pingTaskGroup?.cancel() // Cancel tasks on pause
                            } else {
                                pingStatus = "Pinging..." // Resuming
                                // Start a new ping task for resume
                                 pingTaskGroup = Task {
                                    await startPing()
                                    // Reset status when done
                                    if !stopPinging && !Task.isCancelled {
                                        await MainActor.run {
                                            manager.pingStarted = false
                                             pingStatus = "Completed"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(!manager.pingStarted) // Disable if not started

                    Button("Stop") { // Shorter label
                        stopPing() // Call the stop function
                        pingStatus = "Stopped"
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    // Allow stop if running OR paused
                    .disabled(!manager.pingStarted)

                }
                .padding(.horizontal)
                .padding(.bottom) // Add padding below buttons

            } // End Top Control Area VStack
            .background(Color(NSColor.windowBackgroundColor)) // Match window background

            // --- Header Row for the List ---
             HeaderView() // Use a separate view for the header
             .padding(.horizontal) // Add horizontal padding
             .padding(.vertical, 5) // Add slight vertical padding
             .background(Color.gray.opacity(0.1)) // Subtle background for header


            // --- Results List ---
            if manager.results.isEmpty {
                 Spacer() // Push text to center if list is empty
                 Text("No IP addresses to display.")
                     .foregroundColor(.gray)
                 Spacer() // Push text to center if list is empty
             } else {
                // --- FIX APPLIED HERE ---
                // List will now grow with content up to available space.
                // Scrollbar appears automatically if content exceeds space.
                List {
                    ForEach(manager.results) { result in
                        // Use the Row View for each result
                        ResultRowView(result: result)
                    }
                }
                .listStyle(.plain) // Use plain style
                .environment(\.defaultMinListRowHeight, 25) // Adjust row height
                // Remove maxHeight constraint, keep maxWidth
                .frame(maxWidth: .infinity)
                // --- END OF FIX ---
            }
        }
        .frame(minWidth: 600, minHeight: 400) // Adjust min size as needed
        .navigationTitle("Ping Results") // Keep or remove title as preferred
        .onDisappear {
             // Ensure ping stops if the window is closed
             stopPing()
        }
    }

     // --- Helper: Header View ---
     // (HeaderView struct remains the same as before)
     struct HeaderView: View {
         var body: some View {
             HStack {
                 // Status indicator column (fixed width)
                 Text(" ") // Placeholder for alignment with circle
                     .frame(width: 15, alignment: .center)

                 // IP Address column (flexible width)
                 Text("IP Address")
                     .frame(minWidth: 100, idealWidth: 150, alignment: .leading)

                 // Response Time column (fixed width)
                 Text("Time")
                     .frame(width: 80, alignment: .trailing)

                 // Success Count column (fixed width)
                 Text("Success")
                     .frame(width: 60, alignment: .trailing)

                 // Failure Count column (fixed width)
                 Text("Failures")
                     .frame(width: 60, alignment: .trailing)

                 // Failure Rate column (fixed width)
                 Text("Fail Rate")
                     .frame(width: 70, alignment: .trailing)

                 Spacer() // Pushes columns left
             }
             .font(.caption.weight(.semibold)) // Make header text bold caption
             .foregroundColor(.secondary) // Dim the header text slightly
         }
     }


    // --- Helper: Row View for List ---
    // (ResultRowView struct remains the same as before)
    struct ResultRowView: View {
        let result: PingResult // Receive a single result

        var body: some View {
            HStack {
                // Status Circle
                Circle()
                    .fill(result.isSuccessful ? Color.green : (result.responseTime == "Pending" || result.responseTime == "Pinging..." ? Color.orange : Color.red))
                    .frame(width: 10, height: 10)
                     .padding(.trailing, 5) // Add padding after circle

                // IP Address
                Text(result.ip)
                    .frame(minWidth: 100, idealWidth: 150, alignment: .leading) // Match header frame
                    .lineLimit(1) // Prevent wrapping
                    .truncationMode(.tail) // Truncate if too long

                // Response Time
                Text(result.responseTime)
                    .frame(width: 80, alignment: .trailing) // Match header frame
                    .foregroundColor(result.isSuccessful ? .primary : .secondary) // Dim if failed

                // --- Stats in a single row ---
                 // Success Count
                 Text("\(result.successCount)")
                     .frame(width: 60, alignment: .trailing) // Match header frame

                 // Failure Count
                 Text("\(result.failureCount)")
                     .frame(width: 60, alignment: .trailing) // Match header frame
                     .foregroundColor(result.failureCount > 0 ? .red : .primary) // Highlight failures

                 // Failure Rate
                 Text(String(format: "%.1f%%", result.failureRate)) // Format rate
                     .frame(width: 70, alignment: .trailing) // Match header frame

                 Spacer() // Pushes columns left

            }
            .font(.system(.body, design: .monospaced)) // Use monospaced font for alignment
        }
    }


    // --- Pinging Logic Functions (startPing, ping, parsePingOutput, stopPing) ---
    // (Keep the existing logic functions as they were in the previous version)
    // Function to start continuous pinging
    func startPing() async {
         // Use indices to safely update the array elements on the MainActor
        let indices = manager.results.indices

        // Initialize status for all IPs before starting
         await MainActor.run {
             for index in indices {
                 // Only update if not already pinging (e.g., on resume)
                 if manager.results[index].responseTime != "Pinging..." {
                    manager.results[index].responseTime = "Pinging..."
                    manager.results[index].isSuccessful = false // Reset success status
                 }
             }
         }


        await withTaskGroup(of: Void.self) { group in // Changed return type to Void as updates happen inside
            for index in indices {
                // Check for cancellation/stop/pause before starting next IP loop
                 guard !Task.isCancelled && !stopPinging && !isPaused else {
                     print("Task cancelled or stopped/paused before starting IP \(manager.results.indices.contains(index) ? manager.results[index].ip : "Unknown IP")")
                     break
                 }

                // Ensure index is valid before accessing manager.results
                 guard manager.results.indices.contains(index) else {
                     print("Index \(index) out of bounds before starting task.")
                     continue
                 }
                let ip = manager.results[index].ip

                group.addTask {
                    // Loop for this specific IP until stopped/paused/cancelled
                     while !Task.isCancelled && !stopPinging && !isPaused {
                         // Perform the actual ping
                         let currentResponseTime = await self.ping(ip: ip)
                         let currentSuccess = currentResponseTime != "Timeout" && currentResponseTime != "Error" && currentResponseTime != "No output" && currentResponseTime != "Failed" && currentResponseTime != "Host unknown" && currentResponseTime != "Invalid IP" && currentResponseTime != "Network down"


                         // Update UI immediately for this result
                          await MainActor.run {
                              // Check again inside MainActor run to prevent race conditions
                              // and ensure index is still valid
                              guard manager.results.indices.contains(index), !stopPinging else { return }

                              manager.results[index].responseTime = currentResponseTime
                              manager.results[index].isSuccessful = currentSuccess

                              if currentSuccess {
                                  manager.results[index].successCount += 1
                              } else {
                                  manager.results[index].failureCount += 1
                              }

                              // Recalculate failure rate
                              let totalPings = manager.results[index].successCount + manager.results[index].failureCount
                              if totalPings > 0 {
                                  manager.results[index].failureRate = (Double(manager.results[index].failureCount) / Double(totalPings)) * 100.0
                              } else {
                                   manager.results[index].failureRate = 0.0
                              }
                          }


                         // Sleep for the interval *after* processing the result,
                         // but check for cancellation/stop/pause before sleeping
                         guard !Task.isCancelled && !stopPinging && !isPaused else { break }
                         do {
                             // Use Int64 for interval conversion, provide default
                             let intervalSeconds = Int64(self.interval) ?? 5
                             // Calculate nanoseconds safely
                             let nanoseconds = UInt64(intervalSeconds * 1_000_000_000)
                             // Ensure sleep duration is non-negative
                             if nanoseconds > 0 {
                                 try await Task.sleep(nanoseconds: nanoseconds)
                             } else {
                                 print("Warning: Invalid interval (\(self.interval)), using default sleep.")
                                 try await Task.sleep(nanoseconds: 5 * 1_000_000_000) // Default 5s
                             }
                         } catch {
                              // Task cancelled during sleep
                              print("Sleep cancelled for IP \(ip)")
                              break // Exit the inner while loop if sleep is cancelled
                         }
                     } // End of while loop for single IP
                     print("Exited ping loop for IP \(ip). Cancelled=\(Task.isCancelled), Stopped=\(stopPinging), Paused=\(isPaused)")

                } // End of group.addTask
            } // End of for loop iterating through IPs


             // Task group automatically waits for all added tasks here.
             // If the loop finishes because of cancellation/stop/pause, ensure the group is cancelled
             if Task.isCancelled || stopPinging || isPaused {
                  print("Task group finishing prematurely. Cancelling all remaining tasks.")
                  group.cancelAll()
             } else {
                  print("Task group finishing normally.")
             }


        } // End of withTaskGroup

        // After the task group finishes (or is cancelled/stopped)
        await MainActor.run {
             print("Task group finished execution. Updating final status.")
             // Ensure final status reflects the actual state
             if stopPinging {
                 manager.pingStarted = false
                 pingStatus = "Stopped"
                 print("Final Status: Stopped")
             } else if isPaused {
                 // Keep manager.pingStarted = true if paused to allow resume.
                 manager.pingStarted = true
                 pingStatus = "Paused"
                 print("Final Status: Paused")
             } else if Task.isCancelled {
                 // If cancelled but not explicitly stopped or paused (e.g., window closed)
                 manager.pingStarted = false
                 pingStatus = "Cancelled"
                 print("Final Status: Cancelled")
             }
              else {
                 // Only set to completed if it finished normally
                 manager.pingStarted = false // Mark pinging as finished
                 pingStatus = "Completed"
                 print("Final Status: Completed")
             }
             // Optional: Reset any "Pinging..." status that might remain if tasks ended abruptly
             for index in manager.results.indices {
                 if manager.results[index].responseTime == "Pinging..." {
                     manager.results[index].responseTime = pingStatus // Set to final status
                 }
             }
        }
    }


    // Function to perform a single ping
    func ping(ip: String) async -> String {
        // Basic IP validation
        guard !ip.isEmpty, isValidIPAddress(ip) else { return "Invalid IP" } // Use validation func

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        // Safely convert timeout and size, provide defaults
        let timeoutMs = Int(timeout) ?? 1000
        let packetSize = max(0, Int(size) ?? 56)

        // Arguments: -c 1 (one ping), -W timeout (wait ms), -s size (packet size), ip
        task.arguments = ["-c", "1", "-W", String(timeoutMs), "-s", String(packetSize), ip]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe // Capture errors too

        do {
            try task.run()
            // Asynchronously wait for the process to exit or timeout slightly longer than ping timeout
             async let waitTask: Void = task.waitUntilExit()
             async let readDataTask: Data? = pipe.fileHandleForReading.readToEnd()

             // Timeout mechanism for the process itself (ensure timeoutMs is positive)
             let effectiveTimeoutMs = max(1, timeoutMs) // Ensure at least 1ms
             async let timeoutTask: Void = Task.sleep(nanoseconds: UInt64(effectiveTimeoutMs + 500) * 1_000_000) // Wait slightly longer

            _ = await (try? readDataTask, waitTask, timeoutTask) // Wait for any to finish

            // Check if process is still running after timeout, terminate if needed
            if task.isRunning {
                 print("Ping process for \(ip) exceeded timeout. Terminating.")
                 task.terminate()
                 return "Timeout"
             }

            // Process finished or was terminated, now get the output
            guard let data = try? await readDataTask, let output = String(data: data, encoding: .utf8) else {
                 return task.terminationStatus == 0 ? "No output" : "Failed"
            }

            // Check termination status even if we got output
             if task.terminationStatus != 0 && !output.contains("time=") {
                 print("Ping for \(ip) failed with status \(task.terminationStatus). Output: \(output)")
                 return parsePingError(output) // Use helper for error parsing
             }

             return parsePingOutput(output) // Parse success output

        } catch {
             print("Error running ping process for \(ip): \(error)")
            return "Error"
        }
    }

    // Function to validate IP address format (basic check) - Moved from IPInputView for use here
     func isValidIPAddress(_ ipString: String) -> Bool {
         let parts = ipString.split(separator: ".")
         guard parts.count == 4 else { return false }
         return parts.allSatisfy { part in
             guard let number = Int(part) else { return false }
             return number >= 0 && number <= 255
         }
     }

    // Function to parse successful ping output
    func parsePingOutput(_ output: String) -> String {
         let regex = try? NSRegularExpression(pattern: #"time=(\d+(\.\d+)?)\s*ms"#, options: [])
         if let match = regex?.firstMatch(in: output, options: [], range: NSRange(location: 0, length: output.utf16.count)),
            let range = Range(match.range(at: 1), in: output) {
             let timeValue = String(output[range])
            return "\(timeValue) ms"
         } else {
            // If time= not found in supposedly successful output, mark as failed
            print("Could not parse time from ping output: \(output)")
            return "Failed"
        }
    }

    // Function to parse ping error output
     func parsePingError(_ output: String) -> String {
         if output.contains("timeout") || output.contains("Request timeout") {
             return "Timeout"
         } else if output.contains("cannot resolve") || output.contains("Unknown host") {
             return "Host unknown"
         } else if output.contains("Network is unreachable") {
             return "Network down"
         } else if output.contains("sendto: No route to host") {
             return "No route"
         }
         // Add more specific error checks based on common ping utility messages
         else {
             print("Unknown ping error output: \(output)")
             return "Failed" // Generic failure for unparsed errors
         }
     }


    // Function to stop the pinging process
    func stopPing() {
        print("Stop Ping requested.")
        stopPinging = true
        isPaused = false // Ensure not paused when stopped
        manager.pingStarted = false // Update manager state immediately
        // Cancel the ongoing TaskGroup
        pingTaskGroup?.cancel()
        pingTaskGroup = nil // Clear the task reference
        print("Ping task group cancelled.")
        // Reset individual result statuses on the main thread
         Task {
             await MainActor.run {
                 pingStatus = "Stopped" // Ensure status reflects stop
                 for index in manager.results.indices {
                     // Only update if it was actively pinging or pending
                     if manager.results[index].responseTime == "Pinging..." || manager.results[index].responseTime == "Pending" {
                         manager.results[index].responseTime = "Stopped"
                         manager.results[index].isSuccessful = false
                     }
                 }
             }
         }
    }
}

