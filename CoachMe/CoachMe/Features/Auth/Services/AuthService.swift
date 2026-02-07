//
//  AuthService.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import Foundation
import AuthenticationServices
import Supabase

/// Handles all authentication operations with Sign in with Apple + Supabase sync
/// Per architecture.md: Auth flow sends Apple identity token to Supabase for verification
///
/// Auth Flow:
/// 1. User taps "Sign in with Apple"
/// 2. iOS presents Sign in with Apple sheet
/// 3. On success, receive Apple ID credential with identity token
/// 4. Send identity token to Supabase for verification via signInWithIdToken
/// 5. Supabase creates/updates user, returns session
/// 6. Store Supabase tokens in Keychain
/// 7. Subsequent launches: restore session from Supabase SDK
@MainActor
final class AuthService {
    static let shared = AuthService()

    /// Authentication-specific errors with warm, first-person messages (UX-11)
    enum AuthError: LocalizedError {
        case appleSignInFailed(Error)
        case supabaseAuthFailed(Error)
        case sessionRestoreFailed(Error)
        case noSession
        case invalidCredential
        case tokenEncodingFailed

        var errorDescription: String? {
            switch self {
            case .appleSignInFailed:
                return "I had trouble signing you in. Let's try that again."
            case .supabaseAuthFailed:
                return "I couldn't connect to create your account. Let's try again."
            case .sessionRestoreFailed:
                return "I had trouble remembering you. Please sign in again."
            case .noSession:
                return "You'll need to sign in to continue."
            case .invalidCredential:
                return "I had trouble with your Apple credentials. Let's try again."
            case .tokenEncodingFailed:
                return "I had trouble processing your sign-in. Let's try again."
            }
        }
    }

    /// Current user information (if authenticated)
    struct CurrentUser: Sendable {
        let id: UUID
        let email: String?
        let fullName: String?
    }

    // MARK: - Properties

    private let supabase: SupabaseClient
    private let keychainManager: KeychainManager

    private(set) var currentUser: CurrentUser?

    // MARK: - Initialization

    private init() {
        self.supabase = AppEnvironment.shared.supabase
        self.keychainManager = KeychainManager.shared
    }

    // MARK: - Authentication State

    /// Check if user is currently authenticated
    var isAuthenticated: Bool {
        get async {
            do {
                _ = try await supabase.auth.session
                return true
            } catch {
                return false
            }
        }
    }

    /// Get the current user ID from the session
    /// Returns nil if no valid session exists
    var currentUserId: UUID? {
        get async {
            do {
                let session = try await supabase.auth.session
                return session.user.id
            } catch {
                #if DEBUG
                print("AuthService: Failed to get user ID: \(error.localizedDescription)")
                #endif
                return nil
            }
        }
    }

    /// Get the current access token (for API requests)
    /// Returns nil if no valid session exists
    /// Note: This refreshes the session if expired to ensure a valid token
    var currentAccessToken: String? {
        get async {
            do {
                // First try to get existing session
                let session = try await supabase.auth.session

                // Check if token is expired and refresh if needed
                // The session.expiresAt is Unix timestamp
                if session.expiresAt < Date().timeIntervalSince1970 {
                    #if DEBUG
                    print("AuthService: Access token expired, refreshing...")
                    #endif

                    // Force refresh the session
                    let refreshedSession = try await supabase.auth.refreshSession()
                    return refreshedSession.accessToken
                }

                return session.accessToken
            } catch {
                #if DEBUG
                print("AuthService: Failed to get access token: \(error.localizedDescription)")
                #endif
                return nil
            }
        }
    }

    // MARK: - Auth State Observation

    /// Subscribe to Supabase auth state changes
    /// Call this on app launch to handle token refresh and session events
    func observeAuthStateChanges() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn:
                    if let session = session {
                        try? saveSession(session)
                        currentUser = CurrentUser(
                            id: session.user.id,
                            email: session.user.email,
                            fullName: session.user.userMetadata["full_name"]?.stringValue
                        )
                    }

                    #if DEBUG
                    print("AuthService: Auth state changed - signed in")
                    #endif

                case .signedOut:
                    try? clearSession()
                    currentUser = nil

                    #if DEBUG
                    print("AuthService: Auth state changed - signed out")
                    #endif

                case .tokenRefreshed:
                    if let session = session {
                        try? saveSession(session)
                    }

                    #if DEBUG
                    print("AuthService: Auth state changed - token refreshed")
                    #endif

                case .userUpdated:
                    if let session = session {
                        currentUser = CurrentUser(
                            id: session.user.id,
                            email: session.user.email,
                            fullName: session.user.userMetadata["full_name"]?.stringValue
                        )
                    }

                    #if DEBUG
                    print("AuthService: Auth state changed - user updated")
                    #endif

                default:
                    #if DEBUG
                    print("AuthService: Auth state changed - \(event)")
                    #endif
                }
            }
        }
    }

    // MARK: - Sign In with Apple

    /// Handle Sign in with Apple credential and authenticate with Supabase
    /// - Parameter credential: The Apple ID credential from AuthenticationServices
    /// - Throws: AuthError if authentication fails
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        // Extract identity token from Apple credential
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        do {
            // Sign in with Supabase using Apple's identity token
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityToken
                )
            )

            // Save session to Keychain for persistence
            try saveSession(session)

            // Update current user
            let fullName = formatFullName(from: credential.fullName)
            currentUser = CurrentUser(
                id: session.user.id,
                email: credential.email ?? session.user.email,
                fullName: fullName
            )

            // If we have name/email from first-time sign-in, update user metadata
            // IMPORTANT: Apple only provides fullName and email on FIRST sign-in
            if let fullName = fullName {
                do {
                    try await supabase.auth.update(user: UserAttributes(
                        data: ["full_name": .string(fullName)]
                    ))

                    #if DEBUG
                    print("First-time sign-in: saved full name '\(fullName)' to user metadata")
                    #endif
                } catch {
                    // Non-fatal: metadata update failed but auth succeeded
                    #if DEBUG
                    print("Warning: Failed to save user metadata: \(error.localizedDescription)")
                    #endif
                }
            }

            // Ensure context profile exists (Story 2.1)
            // Non-blocking: profile creation failure shouldn't break auth
            await ensureContextProfileExists(userId: session.user.id)

            #if DEBUG
            print("Successfully signed in user: \(session.user.id)")
            #endif

        } catch {
            #if DEBUG
            print("Supabase signInWithIdToken failed:")
            print("  Error: \(error)")
            print("  Localized: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("  URLError code: \(urlError.code.rawValue)")
            }
            #endif
            throw AuthError.supabaseAuthFailed(error)
        }
    }

    // MARK: - Session Management

    /// Attempt to restore existing session on app launch
    /// - Returns: true if session was restored successfully, false otherwise
    func restoreSession() async throws -> Bool {
        do {
            // Supabase SDK handles session restoration from its internal storage
            let session = try await supabase.auth.session

            // Update current user from session
            currentUser = CurrentUser(
                id: session.user.id,
                email: session.user.email,
                fullName: session.user.userMetadata["full_name"]?.stringValue
            )

            #if DEBUG
            print("Session restored for user: \(session.user.id)")
            #endif

            return true
        } catch {
            // Session doesn't exist or is expired
            currentUser = nil

            #if DEBUG
            print("No valid session to restore: \(error.localizedDescription)")
            #endif

            return false
        }
    }

    /// Sign out the current user and clear all stored credentials
    func signOut() async throws {
        do {
            // Sign out from Supabase
            try await supabase.auth.signOut()

            // Clear Keychain credentials
            try clearSession()

            // Clear current user
            currentUser = nil

            #if DEBUG
            print("User signed out successfully")
            #endif
        } catch {
            // Even if Supabase sign out fails, clear local credentials
            try? clearSession()
            currentUser = nil

            #if DEBUG
            print("Sign out error (credentials cleared anyway): \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Private Helpers

    /// Save session tokens to Keychain
    private func saveSession(_ session: Session) throws {
        try keychainManager.save(session.accessToken, for: .accessToken)
        try keychainManager.save(session.refreshToken, for: .refreshToken)
        try keychainManager.save(session.user.id.uuidString, for: .userId)
    }

    /// Clear all session data from Keychain
    private func clearSession() throws {
        try keychainManager.clearAllAuthData()
    }

    /// Format PersonNameComponents into a display name
    private func formatFullName(from nameComponents: PersonNameComponents?) -> String? {
        guard let nameComponents = nameComponents else { return nil }

        var parts: [String] = []
        if let givenName = nameComponents.givenName {
            parts.append(givenName)
        }
        if let familyName = nameComponents.familyName {
            parts.append(familyName)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Context Profile Integration (Story 2.1)

    /// Ensures a context profile exists for the user
    /// Creates one if it doesn't exist, does nothing if it does
    /// This is non-blocking - failures won't affect authentication
    private func ensureContextProfileExists(userId: UUID) async {
        let repository = ContextRepository.shared

        // Check if profile already exists
        let exists = await repository.profileExists(userId: userId)
        if exists {
            #if DEBUG
            print("AuthService: Context profile already exists for user \(userId)")
            #endif
            return
        }

        // Create new profile
        do {
            _ = try await repository.createProfile(for: userId)

            #if DEBUG
            print("AuthService: Created context profile for user \(userId)")
            #endif
        } catch {
            // Non-fatal: profile creation failure shouldn't block sign-in
            // Profile can be created later when user accesses context features
            #if DEBUG
            print("AuthService: Failed to create context profile (non-fatal): \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - JSON Value Extension for User Metadata

private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
}
