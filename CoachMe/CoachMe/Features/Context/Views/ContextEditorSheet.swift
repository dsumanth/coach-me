//
//  ContextEditorSheet.swift
//  CoachMe
//
//  Story 2.5: Context Profile Viewing & Editing
//  Adaptive editor sheet for editing context items
//  Per architecture.md: Use adaptive design modifiers, VoiceOver accessibility
//

import SwiftUI

/// Sheet for editing context items (values, goals, situation)
/// Uses adaptive glass styling per design system
struct ContextEditorSheet: View {
    // MARK: - Properties

    /// The item being edited
    let editItem: ContextEditItem

    /// Called when user saves the edit
    let onSave: (String) -> Void

    /// Called when user cancels the edit
    let onCancel: () -> Void

    // MARK: - State

    @State private var editedContent: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignConstants.Spacing.lg) {
                // Header with warm prompt
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                    Text(headerPrompt)
                        .font(.subheadline)
                        .foregroundStyle(Color.warmGray500)

                    Text(headerTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Editor field
                if isMultiline {
                    TextEditor(text: $editedContent)
                        .font(.body)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .frame(minHeight: 120)
                        .padding(DesignConstants.Spacing.sm)
                        .background(Color.adaptiveSurface(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input))
                        .focused($isTextFieldFocused)
                        .accessibilityLabel("\(headerTitle) editor")
                } else {
                    TextField(placeholder, text: $editedContent)
                        .font(.body)
                        .padding(DesignConstants.Spacing.md)
                        .background(Color.adaptiveSurface(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.input))
                        .focused($isTextFieldFocused)
                        .accessibilityLabel("\(headerTitle) editor")
                        .submitLabel(.done)
                        .onSubmit {
                            saveIfValid()
                        }
                }

                Spacer()
            }
            .padding(DesignConstants.Spacing.lg)
            .background(Color.adaptiveCream(colorScheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(Color.warmGray500)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveIfValid()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.terracotta)
                    .disabled(editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            editedContent = editItem.currentContent
            // Auto-focus after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTextFieldFocused = true
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Computed Properties

    private var headerPrompt: String {
        switch editItem.type {
        case .value:
            return "What matters to you"
        case .goal:
            return "What you're working toward"
        case .situation:
            return "About your life right now"
        }
    }

    private var headerTitle: String {
        switch editItem.type {
        case .value:
            return "Edit Value"
        case .goal:
            return "Edit Goal"
        case .situation:
            return "Edit Life Situation"
        }
    }

    private var placeholder: String {
        switch editItem.type {
        case .value:
            return "e.g., honesty, family, creativity"
        case .goal:
            return "e.g., get promoted, start a business"
        case .situation:
            return "Tell me about your life right now..."
        }
    }

    private var isMultiline: Bool {
        switch editItem.type {
        case .situation:
            return true
        default:
            return false
        }
    }

    // MARK: - Methods

    private func saveIfValid() {
        let trimmed = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
    }
}

// MARK: - Previews

#Preview("Edit Value") {
    ContextEditorSheet(
        editItem: ContextEditItem(
            type: .value(UUID()),
            currentContent: "honesty and transparency"
        ),
        onSave: { print("Saved: \($0)") },
        onCancel: { print("Cancelled") }
    )
}

#Preview("Edit Goal") {
    ContextEditorSheet(
        editItem: ContextEditItem(
            type: .goal(UUID()),
            currentContent: "Get promoted to senior engineer"
        ),
        onSave: { print("Saved: \($0)") },
        onCancel: { print("Cancelled") }
    )
}

#Preview("Edit Situation") {
    ContextEditorSheet(
        editItem: ContextEditItem(
            type: .situation,
            currentContent: "I'm a software engineer working at a startup, married with two kids"
        ),
        onSave: { print("Saved: \($0)") },
        onCancel: { print("Cancelled") }
    )
}

#Preview("Dark Mode") {
    ContextEditorSheet(
        editItem: ContextEditItem(
            type: .value(UUID()),
            currentContent: "creativity"
        ),
        onSave: { _ in },
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
