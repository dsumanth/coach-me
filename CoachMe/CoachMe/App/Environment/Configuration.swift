//
//  Configuration.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/5/26.
//

import Foundation

enum Environment {
    case development
    case staging
    case production
}

struct Configuration {
    static let current: Environment = .development

    static var supabaseURL: String {
        switch current {
        case .development:
            return "https://xzsvzbjxlsnhxyrglvjp.supabase.co"
        case .staging:
            // TODO: Replace with actual staging Supabase URL when available
            return "https://xzsvzbjxlsnhxyrglvjp.supabase.co"
        case .production:
            // TODO: Replace with actual production Supabase URL when available
            return "https://xzsvzbjxlsnhxyrglvjp.supabase.co"
        }
    }

    /// Supabase Publishable API Key (replaces legacy anon key)
    /// Safe for use in client applications - see https://supabase.com/docs/guides/api/api-keys
    static var supabasePublishableKey: String {
        switch current {
        case .development:
            return "sb_publishable_30dBxpAQbw1rOc8TW0WvQA_JNkRFqIt"
        case .staging:
            // TODO: Replace with staging publishable key when available
            return "sb_publishable_30dBxpAQbw1rOc8TW0WvQA_JNkRFqIt"
        case .production:
            // TODO: Replace with production publishable key when available
            return "sb_publishable_30dBxpAQbw1rOc8TW0WvQA_JNkRFqIt"
        }
    }

    /// Legacy alias for backward compatibility (deprecated - use supabasePublishableKey)
    @available(*, deprecated, renamed: "supabasePublishableKey")
    static var supabaseAnonKey: String {
        supabasePublishableKey
    }

    /// Validates that configuration is properly set
    static func validateConfiguration() -> Bool {
        let isValid = supabaseURL.contains("supabase.co") &&
                      supabasePublishableKey.hasPrefix("sb_publishable_")

        #if DEBUG
        if isValid {
            print("✅ Supabase configuration validated successfully")
        } else {
            print("⚠️ Configuration Warning: Supabase credentials may not be properly configured")
        }
        #endif

        return isValid
    }
}
