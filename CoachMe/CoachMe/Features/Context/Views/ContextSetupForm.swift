//
//  ContextSetupForm.swift
//  CoachMe
//
//  Story 2.2: Context Setup Prompt After First Session
//  Per architecture.md: Use adaptive design modifiers, VoiceOver accessibility
//  Per UX-11: Use warm, first-person placeholder text
//

import SwiftUI

/// Form for users to input their initial context (values, goals, situation)
/// Displayed after user accepts the context prompt
struct ContextSetupForm: View {
    // MARK: - State

    /// User's core values input
    @State private var valuesText: String = ""

    /// User's goals input
    @State private var goalsText: String = ""

    /// User's life situation input
    @State private var situationText: String = ""

    /// Focus state for keyboard management
    @FocusState private var focusedField: Field?

    // MARK: - Actions

    /// Called when user saves their context
    let onSave: (_ values: String, _ goals: String, _ situation: String) -> Void

    /// Called when user skips setup
    let onSkip: () -> Void

    // MARK: - Field Enum

    enum Field: Hashable {
        case values
        case goals
        case situation
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.lg) {
                // Header
                headerSection

                // Form fields
                VStack(spacing: DesignConstants.Spacing.md) {
                    valuesField
                    goalsField
                    situationField
                }

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, DesignConstants.Spacing.lg)
            .padding(.vertical, DesignConstants.Spacing.md)
        }
        .adaptiveGlassSheet()
        .scrollDismissesKeyboard(.interactively)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DesignConstants.Spacing.sm) {
            Text("Tell me about yourself")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Text("Share what matters to you so I can give you more personalized coaching.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignConstants.Spacing.sm)
    }

    // MARK: - Form Fields

    private var valuesField: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
            Text("What's important to you?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(
                "E.g., honesty, growth, family, creativity...",
                text: $valuesText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(2...4)
            .padding(DesignConstants.Spacing.sm)
            .background(Color.warmGray50)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input))
            .focused($focusedField, equals: .values)
            .accessibilityLabel("Your values")
            .accessibilityHint("Enter what's important to you, like honesty, growth, or family")
        }
    }

    private var goalsField: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
            Text("What are you working toward?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(
                "E.g., career change, better relationships, more balance...",
                text: $goalsText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(2...4)
            .padding(DesignConstants.Spacing.sm)
            .background(Color.warmGray50)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input))
            .focused($focusedField, equals: .goals)
            .accessibilityLabel("Your goals")
            .accessibilityHint("Enter what you're working toward, like career change or better relationships")
        }
    }

    private var situationField: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
            Text("Anything else about your situation?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(
                "E.g., I'm a parent of two, work in tech, recently moved cities...",
                text: $situationText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(2...4)
            .padding(DesignConstants.Spacing.sm)
            .background(Color.warmGray50)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input))
            .focused($focusedField, equals: .situation)
            .accessibilityLabel("Your situation")
            .accessibilityHint("Optionally share context about your life situation")
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DesignConstants.Spacing.sm) {
            // Save button - enabled if any field has content
            Button {
                focusedField = nil
                onSave(valuesText, goalsText, situationText)
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignConstants.Size.buttonLarge)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.terracotta)
            .disabled(!hasAnyContent)
            .opacity(hasAnyContent ? 1.0 : DesignConstants.Opacity.disabled)
            .adaptiveInteractiveGlass()
            .accessibilityLabel("Save your context")
            .accessibilityHint(hasAnyContent ? "Saves your values, goals, and situation" : "Enter at least one field to save")

            // Skip button
            Button {
                focusedField = nil
                onSkip()
            } label: {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Skip for now")
            .accessibilityHint("Closes the form without saving. You can set this up later.")
        }
        .padding(.top, DesignConstants.Spacing.md)
    }

    // MARK: - Computed Properties

    /// Returns true if any field has content
    private var hasAnyContent: Bool {
        !valuesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !goalsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !situationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Preview

#Preview("ContextSetupForm - Empty") {
    ContextSetupForm(
        onSave: { values, goals, situation in
            print("Saved: values=\(values), goals=\(goals), situation=\(situation)")
        },
        onSkip: { print("Skipped") }
    )
}

#Preview("ContextSetupForm - Dark") {
    ContextSetupForm(
        onSave: { _, _, _ in },
        onSkip: { }
    )
    .preferredColorScheme(.dark)
}
