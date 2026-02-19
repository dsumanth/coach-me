//
//  AppEnvironment.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/5/26.
//

import Foundation
import Supabase
import SwiftData

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    lazy var supabase: SupabaseClient = {
        guard let url = URL(string: Configuration.supabaseURL) else {
            fatalError("Invalid Supabase URL: \(Configuration.supabaseURL). Check Configuration.swift")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: Configuration.supabasePublishableKey
        )
    }()

    /// SwiftData ModelContainer for offline caching
    /// Initialized lazily to support both app and test contexts
    lazy var modelContainer: ModelContainer = {
        do {
            let schema = Schema([
                CachedContextProfile.self,
                CachedConversation.self,
                CachedMessage.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }()

    /// ModelContext for SwiftData operations
    /// Use this for repository operations that need local persistence
    var modelContext: ModelContext {
        modelContainer.mainContext
    }

    /// Shared subscription view model for trial/subscription state (Story 6.2)
    lazy var subscriptionViewModel = SubscriptionViewModel()

    /// Story 10.3: Shared trial manager for paid-trial-after-discovery lifecycle
    lazy var trialManager = TrialManager.shared

    private init() {
        // Validate configuration on init
        _ = Configuration.validateConfiguration()
    }

    /// Test Supabase connection (DEBUG only)
    /// Call this method to verify the app can reach Supabase
    func testConnection() async {
        #if DEBUG
        do {
            // Attempt to get the current session - throws if no session exists
            let session = try await supabase.auth.session
            print("✅ Supabase connection successful")
            print("   User is signed in: \(session.user.email ?? "unknown")")
        } catch {
            // Session fetch throws when no user is signed in - this is expected behavior
            // and indicates the connection to Supabase is working
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("session") || errorMessage.contains("jwt") || errorMessage.contains("not authenticated") {
                // These errors mean connection worked but no user session exists
                print("✅ Supabase connection successful (no active session - user not signed in)")
            } else {
                print("❌ Supabase connection failed: \(error.localizedDescription)")
            }
        }
        #endif
    }
}
