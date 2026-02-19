//
//  StyleOverrideSheet.swift
//  CoachMe
//
//  Story 8.8: Enhanced Profile — Learned Knowledge Display
//  Sheet for manually setting coaching style preference
//

import SwiftUI

/// Sheet for selecting a manual coaching style override
/// Manual overrides always win over inferred style
struct StyleOverrideSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    @Bindable var viewModel: ContextViewModel

    // MARK: - Local State

    @State private var selectedStyle: String?

    // MARK: - Style Options

    private static let styleOptions: [(name: String, description: String)] = [
        ("Direct", "Clear, actionable advice without beating around the bush"),
        ("Exploratory", "Thoughtful questions that help you discover your own answers"),
        ("Balanced", "A mix of direction and exploration depending on what's needed"),
        ("Playful", "Human, lightly humorous coaching with practical, relatable examples"),
        ("Compassionate", "Warm encouragement and validation before pushing action"),
        ("Challenging", "Honest pushback that helps you grow beyond your comfort zone")
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.lg) {
                    // Show inferred style if it exists
                    if let inferredStyle = viewModel.coachingStyle?.inferredStyle {
                        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                            Text("Learned preference")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.warmGray400)

                            Text(inferredStyle)
                                .font(.body)
                                .foregroundStyle(Color.warmGray500)
                        }
                        .padding(.horizontal, DesignConstants.Spacing.lg)
                    }

                    // Style options
                    VStack(spacing: DesignConstants.Spacing.sm) {
                        ForEach(Self.styleOptions, id: \.name) { option in
                            styleOptionRow(option)
                        }
                    }
                    .padding(.horizontal, DesignConstants.Spacing.lg)

                    // Reset button (only when manual override is active)
                    if viewModel.hasManualStyleOverride {
                        Button {
                            Task {
                                await viewModel.clearStyleOverride()
                                if !viewModel.showError {
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Reset to learned")
                                .font(.subheadline)
                                .foregroundStyle(Color.terracotta)
                                .frame(maxWidth: .infinity)
                                .frame(height: DesignConstants.Size.buttonMedium)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DesignConstants.Spacing.lg)
                        .accessibilityLabel("Reset to learned style preference")
                        .accessibilityHint("Removes your manual override and uses the learned preference")
                    }
                }
                .padding(.vertical, DesignConstants.Spacing.md)
            }
            .background(Color.adaptiveCream(colorScheme).ignoresSafeArea())
            .navigationTitle("Coaching Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.terracotta)
                }
            }
        }
        .onAppear {
            selectedStyle = viewModel.effectiveCoachingStyle
        }
        .alert("Oops", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error?.errorDescription ?? "Something went wrong")
        }
    }

    // MARK: - Style Option Row

    private func styleOptionRow(_ option: (name: String, description: String)) -> some View {
        Button {
            selectedStyle = option.name
            Task {
                await viewModel.setStyleOverride(option.name)
                if !viewModel.showError {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: DesignConstants.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.xxs) {
                    Text(option.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(Color.warmGray500)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if selectedStyle == option.name {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.terracotta)
                }
            }
            .padding(.vertical, DesignConstants.Spacing.sm)
            .padding(.horizontal, DesignConstants.Spacing.md)
            .adaptiveGlass()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.name) style")
        .accessibilityHint(option.description)
        .accessibilityAddTraits(selectedStyle == option.name ? .isSelected : [])
    }
}
