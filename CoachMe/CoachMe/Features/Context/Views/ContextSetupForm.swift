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
    @Environment(\.colorScheme) private var colorScheme

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
                "",
                text: $valuesText,
                prompt: Text("E.g., honesty, growth, family, creativity...")
                    .foregroundStyle(fieldPlaceholderColor),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .foregroundColor(fieldTextColor)
            .lineLimit(1...4)
            .padding(.horizontal, DesignConstants.Spacing.sm)
            .padding(.vertical, 10)
            .modifier(GlassInputBackground())
            .focused($focusedField, equals: .values)
            .tint(.accentColor)
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
                "",
                text: $goalsText,
                prompt: Text("E.g., career change, better relationships, more balance...")
                    .foregroundStyle(fieldPlaceholderColor),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .foregroundColor(fieldTextColor)
            .lineLimit(1...4)
            .padding(.horizontal, DesignConstants.Spacing.sm)
            .padding(.vertical, 10)
            .modifier(GlassInputBackground())
            .focused($focusedField, equals: .goals)
            .tint(.accentColor)
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
                "",
                text: $situationText,
                prompt: Text("E.g., I'm a parent of two, work in tech, recently moved cities...")
                    .foregroundStyle(fieldPlaceholderColor),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .foregroundColor(fieldTextColor)
            .lineLimit(1...4)
            .padding(.horizontal, DesignConstants.Spacing.sm)
            .padding(.vertical, 10)
            .modifier(GlassInputBackground())
            .focused($focusedField, equals: .situation)
            .tint(.accentColor)
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
                onSave(
                    valuesText.trimmingCharacters(in: .whitespacesAndNewlines),
                    goalsText.trimmingCharacters(in: .whitespacesAndNewlines),
                    situationText.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignConstants.Size.buttonLarge)
                    .background(
                        RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.interactive, style: .continuous)
                            .fill(hasAnyContent ? Color.terracotta : Color.terracotta.opacity(0.55))
                    )
            }
            .disabled(!hasAnyContent)
            .opacity(hasAnyContent ? 1.0 : DesignConstants.Opacity.disabled)
            .accessibilityLabel("Save your context")
            .accessibilityHint(hasAnyContent ? "Saves your values, goals, and situation" : "Enter at least one field to save")

            // Skip button
            Button {
                focusedField = nil
                onSkip()
            } label: {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.88) : Color.warmGray700)
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

    private var fieldTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.95) : Color.warmGray900
    }

    private var fieldPlaceholderColor: Color {
        colorScheme == .dark ? .white.opacity(0.48) : Color.warmGray500.opacity(0.9)
    }
}

private struct GlassInputBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input, style: .continuous)

        if #available(iOS 26, *) {
            content
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.03))
                }
                .overlay(
                    shape
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.26), lineWidth: 1)
                )
                .clipShape(shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(
                    shape
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.24), lineWidth: 1)
                )
                .clipShape(shape)
        }
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
