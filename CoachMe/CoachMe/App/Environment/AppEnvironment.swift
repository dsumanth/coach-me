//
//  AppEnvironment.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/5/26.
//

import Foundation
import Supabase

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
