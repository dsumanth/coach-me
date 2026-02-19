//
//  CoachMeApp.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/5/26.
//

import SwiftUI
import SwiftData
import RevenueCat

@main
struct CoachMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // RevenueCat SDK initialization (Story 6.1)
        // Skip during unit tests — RevenueCat's C-level code causes malloc double-free crashes
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let rcKey = Configuration.revenueCatAPIKey
            if !rcKey.isEmpty {
                #if DEBUG
                Purchases.logLevel = .debug
                #endif
                Purchases.configure(withAPIKey: rcKey)
            } else {
                #if DEBUG
                print("RevenueCat: API key not configured, subscription features disabled")
                #endif
            }
        }

        // Story 7.3: Start network observation for automatic sync on reconnect
        // Skip during unit tests — the polling loop and NWPathMonitor cause hangs
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            _ = OfflineSyncService.shared
        }

        // Story 8.3: Reset session-scoped push prompt dismissal on each app launch
        // so "Not now" only suppresses for the current session, not permanently
        // Skip during unit tests to preserve test isolation
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            PushPermissionService.shared.resetSessionDismissal()
        }
    }

    /// True when running inside the XCTest host process.
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                // Render nothing during unit tests — the full UI triggers
                // auth restoration → RevenueCat C-level code → malloc double-free crash.
                // Tests use mocks and don't need the live app UI.
                Color.clear
            } else {
                RootView()
            }
        }
        // Use AppEnvironment's modelContainer as single source of truth
        // This ensures ContextRepository and SwiftUI views share the same container
        .modelContainer(AppEnvironment.shared.modelContainer)
    }
}
