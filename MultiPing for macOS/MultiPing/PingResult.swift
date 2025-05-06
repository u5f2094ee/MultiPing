import Foundation
import Combine // Needed for ObservableObject

// Converted to a class conforming to ObservableObject
class PingResult: ObservableObject, Identifiable, Equatable { // Added Equatable
    let id = UUID() // Stays the same for Identifiable & Equatable
    let ip: String  // IP doesn't change

    // Properties that change are marked @Published
    @Published var responseTime: String
    @Published var successCount: Int
    @Published var failureCount: Int
    @Published var failureRate: Double
    @Published var isSuccessful: Bool

    // Initializer for the class
    init(ip: String, responseTime: String, successCount: Int, failureCount: Int, failureRate: Double, isSuccessful: Bool) {
        self.ip = ip
        self.responseTime = responseTime
        self.successCount = successCount
        self.failureCount = failureCount
        self.failureRate = failureRate
        self.isSuccessful = isSuccessful
    }

    // Equatable conformance based on ID
    static func == (lhs: PingResult, rhs: PingResult) -> Bool {
        return lhs.id == rhs.id
    }

    // Helper to reset counts and status (useful for start/clear)
    func resetStats(initialStatus: String = "Pending") {
        // Ensure updates happen on the main thread if called from background
        // However, since @Published handles this, direct assignment is okay here.
        self.responseTime = initialStatus
        self.successCount = 0
        self.failureCount = 0
        self.failureRate = 0.0
        self.isSuccessful = false
    }
}

