//
//  Untitled.swift
//  MultiPing
//
//  Created by ZZ on 2025-04-26.
//

import Foundation

class PingManager: ObservableObject {
    @Published var ipInput: String = ""
    @Published var results: [PingResult] = []
    @Published var pingStarted = false
}
