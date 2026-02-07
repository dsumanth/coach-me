//
//  SettingsView.swift
//  CoachMe
//
//  Created by Claude Code on 2/7/26.
//
//  Story 2.6: Settings screen with "Clear all conversations" option
//

import SwiftUI

/// Settings screen with conversation management options
/// Per architecture.md: Apply adaptive design modifiers, never raw .glassEffect()
struct SettingsView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            // Warm background
            Color.cream
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Data Management Section
                    dataManagementSection
                }
                .padding(16)
            }

            // Loading overlay during deletion
            if viewModel.isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Clearing your conversations...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityLabel("Clearing all conversations")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(Color.terracotta)
            }
        }
        // Delete all confirmation alert (Task 5.4)
        .allConversationsDeleteAlert(isPresented: $viewModel.showDeleteAllConfirmation) {
            Task {
                let success = await viewModel.deleteAllConversations()
                if success {
                    dismiss()
                }
            }
        }
        // Error alert
        .alert("Oops", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error?.errorDescription ?? "Something went wrong")
        }
    }

    // MARK: - Sections

    /// Data management section with clear all conversations option
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.warmGray500)
                .padding(.horizontal, 4)

            // Clear all conversations row (Task 5.2)
            VStack(spacing: 0) {
                Button {
                    viewModel.showDeleteAllConfirmation = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.red)

                                Text("Clear all conversations")
                                    .font(.body)
                                    .foregroundStyle(Color.warmGray900)
                            }

                            Text("This will remove all your conversation history")
                                .font(.caption)
                                .foregroundStyle(Color.warmGray500)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.warmGray400)
                    }
                    .padding(16)
                }
                .accessibilityLabel("Clear all conversations")
                .accessibilityHint("Tap to remove all your conversation history")
            }
            .background(Color.warmGray50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .adaptiveGlass()  // Task 5.6
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
