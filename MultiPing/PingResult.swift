//
//  Untitled.swift
//  MultiPing
//
//  Created by ZZ on 2025-04-27.
//

import Foundation

struct PingResult: Identifiable {
    let id = UUID()
    let ip: String
    var responseTime: String
    var successCount: Int
    var failureCount: Int
    var failureRate: Double  // Add failureRate property here
    var isSuccessful: Bool
}
