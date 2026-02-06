//
//  NetworkMonitor.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import Foundation
import Network

/// Monitors network connectivity status
/// Per architecture.md: Use @Observable for observable state
@MainActor
@Observable
final class NetworkMonitor {
    // MARK: - Published State

    /// Whether the device is connected to the internet
    private(set) var isConnected = true

    /// Whether the connection is expensive (cellular)
    private(set) var isExpensive = false

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - Singleton

    /// Shared instance for app-wide network monitoring
    static let shared = NetworkMonitor()

    // MARK: - Initialization

    init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
    }

    /// Testing initializer that allows setting initial connection state
    /// Fix for code review H2/M4: Enable dependency injection for testing
    init(isConnected: Bool, isExpensive: Bool = false) {
        self.monitor = NWPathMonitor()
        self.isConnected = isConnected
        self.isExpensive = isExpensive
        // Don't start monitoring in test mode - state is manually controlled
    }

    /// Internal method for tests to update connection state
    func setConnectionState(isConnected: Bool, isExpensive: Bool = false) {
        self.isConnected = isConnected
        self.isExpensive = isExpensive
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
            }
        }
        monitor.start(queue: queue)
    }
}
