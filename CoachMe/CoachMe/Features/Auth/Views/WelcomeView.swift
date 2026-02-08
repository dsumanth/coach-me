//
//  WelcomeView.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI
import AuthenticationServices

/// Welcome screen with Sign in with Apple button
/// Per architecture.md: Apply warm color palette from Colors.swift
struct WelcomeView: View {
    @State private var viewModel = AuthViewModel()
    @Environment(\.colorScheme) private var colorScheme

    /// Callback when authentication succeeds
    var onAuthenticated: (() -> Void)?

    /// Terms of Service URL — shared via AppURLs (Story 4.3)
    private static let termsOfServiceURL = AppURLs.termsOfService

    var body: some View {
        ZStack {
            // Warm background
            Color.adaptiveCream(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App branding section
                brandingSection

                Spacer()

                // Sign in section
                signInSection

                // Disclaimer section
                disclaimerSection
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)

            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .alert("Oops", isPresented: $viewModel.showError) {
            Button("Try Again", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error?.errorDescription ?? "Something went wrong")
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                onAuthenticated?()
            }
        }
    }

    // MARK: - Subviews

    /// App branding with logo and tagline
    private var brandingSection: some View {
        VStack(spacing: 16) {
            // App icon placeholder
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.terracotta)
                .accessibilityHidden(true)

            // App name
            Text("Coach")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(Color.adaptiveText(colorScheme))

            // Tagline
            Text("Your personal coach,\nwhenever you need")
                .font(.title3)
                .foregroundColor(Color.adaptiveText(colorScheme, isPrimary: false))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach App. Your personal coach, whenever you need.")
    }

    /// Sign in with Apple button and section
    private var signInSection: some View {
        VStack(spacing: 20) {
            // Explanatory text
            Text("Sign in to save your conversations\nand get personalized coaching")
                .font(.subheadline)
                .foregroundColor(Color.adaptiveText(colorScheme, isPrimary: false))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            // Sign in with Apple button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                viewModel.handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Sign in with Apple")
            .accessibilityHint("Creates or signs into your account using your Apple ID")
        }
        .padding(.bottom, 32)
    }

    /// Coaching disclaimer per FR19
    private var disclaimerSection: some View {
        VStack(spacing: 8) {
            Text("AI coaching, not therapy or mental health treatment")
                .font(.caption)
                .foregroundColor(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.88))
                .multilineTextAlignment(.center)

            Link(destination: Self.termsOfServiceURL) {
                Text("View Terms of Service")
                    .font(.caption)
                    .foregroundColor(Color.terracotta)
            }
            .accessibilityLabel("View Terms of Service")
            .accessibilityHint("Opens the terms of service in Safari")
        }
    }

    /// Loading overlay while authentication is in progress
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Color.adaptiveText(colorScheme))

                Text("Signing in...")
                    .font(.subheadline)
                    .foregroundColor(Color.adaptiveText(colorScheme))
            }
            .padding(32)
            .background(Color.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signing in. Please wait.")
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
}
