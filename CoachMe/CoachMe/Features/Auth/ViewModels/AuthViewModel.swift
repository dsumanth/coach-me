//
//  AuthViewModel.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import Foundation
import AuthenticationServices

/// ViewModel for authentication flow
/// Per architecture.md: Use @Observable for ViewModels (not @ObservableObject)
@MainActor
@Observable
final class AuthViewModel {
    // MARK: - Published State

    /// Whether the user is currently authenticated
    var isAuthenticated = false

    /// Whether an authentication operation is in progress
    var isLoading = false

    /// Current authentication error (if any)
    var error: AuthService.AuthError?

    /// Whether to show the error alert
    var showError = false

    // MARK: - Dependencies

    private let authService = AuthService.shared

    /// Currently running sign-in task (for cancellation support)
    private var signInTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {}

    // MARK: - Sign In with Apple

    /// Handle the result from Sign in with Apple
    /// - Parameter result: The authorization result from AuthenticationServices
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        // Cancel any existing sign-in task
        signInTask?.cancel()

        signInTask = Task {
            await performAppleSignIn(result: result)
        }
    }

    /// Cancel any ongoing authentication operation
    /// Call this when the view is dismissed or navigation occurs during auth
    func cancelAuthentication() {
        signInTask?.cancel()
        signInTask = nil
        isLoading = false
    }

    /// Perform the async Sign in with Apple flow
    private func performAppleSignIn(result: Result<ASAuthorization, Error>) async {
        // Check for cancellation at start
        guard !Task.isCancelled else { return }

        isLoading = true
        error = nil

        defer {
            isLoading = false
            signInTask = nil
        }

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                error = .invalidCredential
                showError = true
                return
            }

            do {
                // Check for cancellation before network call
                guard !Task.isCancelled else { return }

                try await authService.signInWithApple(credential: appleIDCredential)

                // Check for cancellation after network call
                guard !Task.isCancelled else { return }

                isAuthenticated = true

                #if DEBUG
                print("AuthViewModel: Sign in successful")
                #endif

            } catch is CancellationError {
                // Task was cancelled, don't show error
                #if DEBUG
                print("AuthViewModel: Sign in cancelled")
                #endif

            } catch let authError as AuthService.AuthError {
                guard !Task.isCancelled else { return }
                error = authError
                showError = true

                #if DEBUG
                print("AuthViewModel: Sign in failed - \(authError.localizedDescription)")
                #endif

            } catch {
                guard !Task.isCancelled else { return }
                self.error = .appleSignInFailed(error)
                showError = true

                #if DEBUG
                print("AuthViewModel: Unexpected error - \(error.localizedDescription)")
                #endif
            }

        case .failure(let authError):
            // Check if user canceled - don't show error for cancellation
            if let error = authError as? ASAuthorizationError,
               error.code == .canceled {
                #if DEBUG
                print("AuthViewModel: User canceled Sign in with Apple")
                #endif
                return
            }

            guard !Task.isCancelled else { return }
            error = .appleSignInFailed(authError)
            showError = true

            #if DEBUG
            print("AuthViewModel: Apple Sign In failed - \(authError.localizedDescription)")
            #endif
        }
    }

    // MARK: - Session Management

    /// Check for existing session on app launch
    /// Call this when the app starts to restore authentication state
    func checkExistingSession() async {
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let hasSession = try await authService.restoreSession()
            isAuthenticated = hasSession

            #if DEBUG
            print("AuthViewModel: Session check complete - authenticated: \(hasSession)")
            #endif

        } catch {
            isAuthenticated = false

            #if DEBUG
            print("AuthViewModel: Session check failed - \(error.localizedDescription)")
            #endif
        }
    }

    /// Sign out the current user
    func signOut() async {
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            try await authService.signOut()
            isAuthenticated = false
            error = nil

            #if DEBUG
            print("AuthViewModel: Sign out successful")
            #endif

        } catch {
            // Even if sign out fails on server, clear local state
            isAuthenticated = false

            #if DEBUG
            print("AuthViewModel: Sign out completed with error - \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Error Handling

    /// Dismiss the current error
    func dismissError() {
        showError = false
        error = nil
    }
}
