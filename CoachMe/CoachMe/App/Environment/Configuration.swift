//
//  Configuration.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/5/26.
//

import Foundation

/// Build environment configuration (renamed to avoid SwiftUI @Environment conflict)
enum BuildEnvironment: String {
    case development
    case staging
    case production
}

struct Configuration {
    /// Current environment - determined by build configuration
    /// To set up different environments:
    /// 1. In Xcode, go to Project > Build Settings
    /// 2. Add a user-defined setting: COACH_ENV = development | staging | production
    /// 3. In Info.plist, add: CoachEnvironment = $(COACH_ENV)
    /// 4. Create separate schemes for each environment
    static let current: BuildEnvironment = {
        // Check Info.plist for environment override
        if let envString = Bundle.main.infoDictionary?["CoachEnvironment"] as? String,
           let env = BuildEnvironment(rawValue: envString.lowercased()) {
            return env
        }

        // Fallback: use DEBUG flag
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()

    static var supabaseURL: String {
        switch current {
        case .development:
            return "https://xzsvzbjxlsnhxyrglvjp.supabase.co"
        case .staging:
            // FIXME: Set staging Supabase URL before deploying to TestFlight
            return envValue(for: "SUPABASE_URL_STAGING") ?? "https://STAGING-PROJECT.supabase.co"
        case .production:
            // FIXME: Set production Supabase URL before App Store release
            return envValue(for: "SUPABASE_URL_PRODUCTION") ?? "https://PRODUCTION-PROJECT.supabase.co"
        }
    }

    /// Supabase Publishable API Key (replaces legacy anon key)
    /// Safe for use in client applications - see https://supabase.com/docs/guides/api/api-keys
    static var supabasePublishableKey: String {
        switch current {
        case .development:
            return "sb_publishable_30dBxpAQbw1rOc8TW0WvQA_JNkRFqIt"
        case .staging:
            // FIXME: Set staging publishable key before deploying to TestFlight
            return envValue(for: "SUPABASE_KEY_STAGING") ?? "sb_publishable_STAGING_KEY"
        case .production:
            // FIXME: Set production publishable key before App Store release
            return envValue(for: "SUPABASE_KEY_PRODUCTION") ?? "sb_publishable_PRODUCTION_KEY"
        }
    }

    /// Read environment variable from Info.plist (set via xcconfig or build settings)
    private static func envValue(for key: String) -> String? {
        Bundle.main.infoDictionary?[key] as? String
    }

    /// Legacy alias for backward compatibility (deprecated - use supabasePublishableKey)
    @available(*, deprecated, renamed: "supabasePublishableKey")
    static var supabaseAnonKey: String {
        supabasePublishableKey
    }

    /// Validates that configuration is properly set
    /// - Returns: true if configuration appears valid
    static func validateConfiguration() -> Bool {
        let urlValid = supabaseURL.contains("supabase.co") &&
                       !supabaseURL.contains("STAGING-PROJECT") &&
                       !supabaseURL.contains("PRODUCTION-PROJECT")

        let keyValid = supabasePublishableKey.hasPrefix("sb_publishable_") &&
                       !supabasePublishableKey.contains("STAGING_KEY") &&
                       !supabasePublishableKey.contains("PRODUCTION_KEY")

        let isValid = urlValid && keyValid

        #if DEBUG
        print("🔧 Environment: \(current.rawValue)")
        if isValid {
            print("✅ Supabase configuration validated successfully")
        } else {
            print("⚠️ Configuration Warning: Supabase credentials may not be properly configured")
            if !urlValid {
                print("   - Supabase URL needs to be set for \(current.rawValue) environment")
            }
            if !keyValid {
                print("   - Supabase key needs to be set for \(current.rawValue) environment")
            }
        }
        #endif

        // In non-debug builds for staging/production, fail loudly if not configured
        #if !DEBUG
        if current != .development && !isValid {
            assertionFailure("Configuration Error: Supabase credentials not properly configured for \(current.rawValue)")
        }
        #endif

        return isValid
    }
}
