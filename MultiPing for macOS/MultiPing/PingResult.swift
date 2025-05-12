import Foundation
import Combine // Needed for ObservableObject

// Define an enum for target types
enum TargetType: String, Codable, CaseIterable { // Added CaseIterable for potential future use
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"
    case domain = "Domain"
    case unknown = "Unknown" // For fallback or initial state
}

// Converted to a class conforming to ObservableObject
class PingResult: ObservableObject, Identifiable, Equatable { // Added Equatable
    let id = UUID() // Stays the same for Identifiable & Equatable
    let targetValue: String  // Renamed from 'ip' to be more generic
    let targetType: TargetType // New property to store the type

    // Properties that change are marked @Published
    @Published var responseTime: String
    @Published var successCount: Int
    @Published var failureCount: Int
    @Published var failureRate: Double
    @Published var isSuccessful: Bool

    // Initializer for the class
    init(targetValue: String, targetType: TargetType, responseTime: String, successCount: Int, failureCount: Int, failureRate: Double, isSuccessful: Bool) {
        self.targetValue = targetValue
        self.targetType = targetType // Initialize the new property
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

    // Convenience accessor for display name, which is always the targetValue
    var displayName: String {
        return targetValue
    }
}

