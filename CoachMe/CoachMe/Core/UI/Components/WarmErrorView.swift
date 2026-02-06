//
//  WarmErrorView.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

/// Warm, first-person error message component
/// Per UX spec: "I couldn't connect right now" not "Error 503"
struct WarmErrorView: View {
    // MARK: - Properties

    /// The warm, first-person error message
    let message: String

    /// Optional retry action
    var retryAction: (() -> Void)? = nil

    /// Optional custom icon (defaults to exclamationmark.circle)
    var icon: String = "exclamationmark.circle"

    // MARK: - Environment

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.adaptiveTerracotta(colorScheme).opacity(0.8))
                .accessibilityHidden(true)

            Text(message)
                .font(Typography.errorMessage)
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("Try Again")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color.adaptiveTerracotta(colorScheme))
                }
                .padding(.top, 4)
                .accessibilityHint("Double tap to retry")
            }
        }
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - First-Person Error Messages

/// Centralized first-person error messages for consistent warm tone
/// Per UX spec: All errors should feel helpful, not technical
enum WarmErrorMessages {
    /// Network connection failed
    static let connectionFailed = "I couldn't connect right now. Let's try again in a moment."

    /// Failed to load content
    static let loadFailed = "I had trouble loading that. Give me another try?"

    /// Failed to save changes
    static let saveFailed = "I couldn't save your changes. Let's try that again."

    /// Session expired
    static let sessionExpired = "It's been a while — let me reconnect for you."

    /// Server error
    static let serverError = "Something went wrong on my end. I'm working on it."

    /// Request timeout
    static let timeout = "That took longer than expected. Let's try again."

    /// No network available
    static let networkUnavailable = "I need an internet connection to help you right now."

    /// Generic error fallback
    static let generic = "Something didn't work quite right. Let's try again?"

    /// Permission denied
    static let permissionDenied = "I need your permission to do that. You can enable it in Settings."

    /// Content not found
    static let notFound = "I couldn't find what you're looking for."

    /// Rate limited
    static let rateLimited = "Let's take a breath. You can continue in a moment."
}

// MARK: - Convenience Initializers

extension WarmErrorView {
    /// Connection failed error
    static func connectionFailed(onRetry: @escaping () -> Void) -> WarmErrorView {
        WarmErrorView(
            message: WarmErrorMessages.connectionFailed,
            retryAction: onRetry,
            icon: "wifi.exclamationmark"
        )
    }

    /// Load failed error
    static func loadFailed(onRetry: @escaping () -> Void) -> WarmErrorView {
        WarmErrorView(
            message: WarmErrorMessages.loadFailed,
            retryAction: onRetry
        )
    }

    /// Timeout error
    static func timeout(onRetry: @escaping () -> Void) -> WarmErrorView {
        WarmErrorView(
            message: WarmErrorMessages.timeout,
            retryAction: onRetry,
            icon: "clock.badge.exclamationmark"
        )
    }

    /// Server error
    static func serverError(onRetry: (() -> Void)? = nil) -> WarmErrorView {
        WarmErrorView(
            message: WarmErrorMessages.serverError,
            retryAction: onRetry,
            icon: "server.rack"
        )
    }

    /// Offline error (no retry - user needs to restore connection)
    static var offline: WarmErrorView {
        WarmErrorView(
            message: WarmErrorMessages.networkUnavailable,
            icon: "wifi.slash"
        )
    }
}

// MARK: - Preview

#Preview("Warm Error Views") {
    ScrollView {
        VStack(spacing: 32) {
            WarmErrorView.connectionFailed { print("Retry") }

            Divider()

            WarmErrorView.loadFailed { print("Retry") }

            Divider()

            WarmErrorView.timeout { print("Retry") }

            Divider()

            WarmErrorView.serverError()

            Divider()

            WarmErrorView.offline
        }
        .padding()
    }
    .background(Color.cream)
}

#Preview("Warm Error - Dark Mode") {
    WarmErrorView.connectionFailed { print("Retry") }
        .padding()
        .background(Color.creamDark)
        .preferredColorScheme(.dark)
}
