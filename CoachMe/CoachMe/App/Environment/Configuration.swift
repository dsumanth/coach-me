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
    /// Current environment - determined by xcconfig (CoachEnvironment key in Info.plist)
    /// Set INFOPLIST_KEY_CoachEnvironment in Debug.xcconfig / Release.xcconfig
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

    /// Supabase URL - read from Info.plist (injected via xcconfig)
    /// Set values in Debug.xcconfig / Release.xcconfig (see Config.xcconfig.template)
    static var supabaseURL: String {
        guard let url = envValue(for: "SupabaseURL"), !url.isEmpty else {
            fatalError("SupabaseURL not configured. Copy Config.xcconfig.template to Debug.xcconfig and fill in your values.")
        }
        return url
    }

    /// Supabase Publishable API Key - read from Info.plist (injected via xcconfig)
    /// Safe for use in client applications - see https://supabase.com/docs/guides/api/api-keys
    static var supabasePublishableKey: String {
        guard let key = envValue(for: "SupabasePublishableKey"), !key.isEmpty else {
            fatalError("SupabasePublishableKey not configured. Copy Config.xcconfig.template to Debug.xcconfig and fill in your values.")
        }
        return key
    }

    /// RevenueCat Public API Key - read from Info.plist (injected via xcconfig)
    /// Returns empty string in DEBUG if not configured (allows development without key)
    /// Fatals in release builds if not configured
    static var revenueCatAPIKey: String {
        guard let key = envValue(for: "RevenueCatAPIKey"), !key.isEmpty else {
            #if DEBUG
            print("Warning: RevenueCatAPIKey not configured. Subscription features disabled.")
            return ""
            #else
            fatalError("RevenueCatAPIKey not configured.")
            #endif
        }
        return key
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
                       !supabaseURL.contains("YOUR_PROJECT") &&
                       !supabaseURL.contains("PRODUCTION-PROJECT")

        let keyValid = supabasePublishableKey.hasPrefix("sb_publishable_") &&
                       !supabasePublishableKey.contains("YOUR_KEY_HERE") &&
                       !supabasePublishableKey.contains("PRODUCTION_KEY")

        let rcKeyValid = !revenueCatAPIKey.isEmpty &&
                        !revenueCatAPIKey.contains("your_revenuecat")

        let isValid = urlValid && keyValid

        #if DEBUG
        print("🔧 Environment: \(current.rawValue)")
        if isValid {
            print("✅ Supabase configuration validated successfully")
        } else {
            print("⚠️ Configuration Warning: Supabase credentials may not be properly configured")
            if !urlValid {
                print("   - Supabase URL needs to be set in xcconfig for \(current.rawValue) environment")
            }
            if !keyValid {
                print("   - Supabase key needs to be set in xcconfig for \(current.rawValue) environment")
            }
        }
        if rcKeyValid {
            print("✅ RevenueCat configuration validated successfully")
        } else {
            print("⚠️ RevenueCat API key not configured — subscription features will be disabled")
        }
        #endif

        #if !DEBUG
        if !isValid {
            fatalError("Configuration Error: Supabase credentials not properly configured for \(current.rawValue)")
        }
        if !rcKeyValid {
            fatalError("Configuration Error: RevenueCat API key not configured for \(current.rawValue)")
        }
        #endif

        return isValid
    }
}
