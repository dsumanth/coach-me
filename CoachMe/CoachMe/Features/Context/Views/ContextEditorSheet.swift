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
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.95) : Color.warmGray900)
                        .frame(minHeight: 120)
                        .padding(DesignConstants.Spacing.sm)
                        .modifier(ContextEditorInputSurfaceModifier(colorScheme: colorScheme))
                        .focused($isTextFieldFocused)
                        .accessibilityLabel("\(headerTitle) editor")
                } else {
                    TextField(
                        "",
                        text: $editedContent,
                        prompt: Text(placeholder)
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.45) : Color.warmGray500.opacity(0.9))
                    )
                        .font(.body)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.95) : Color.warmGray900)
                        .padding(DesignConstants.Spacing.md)
                        .modifier(ContextEditorInputSurfaceModifier(colorScheme: colorScheme))
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
            .adaptiveGlassSheet()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.88) : Color.warmGray600)
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
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
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
        case .discoveryField(let key):
            switch key {
            case .ahaInsight: return "A key insight about you"
            case .vision: return "Where you see yourself going"
            case .communicationStyle: return "How you like to communicate"
            case .emotionalBaseline: return "Your emotional starting point"
            }
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
        case .discoveryField(let key):
            switch key {
            case .ahaInsight: return "Edit Insight"
            case .vision: return "Edit Vision"
            case .communicationStyle: return "Edit Communication Style"
            case .emotionalBaseline: return "Edit Emotional Baseline"
            }
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
        case .discoveryField(let key):
            switch key {
            case .ahaInsight: return "e.g., I thrive when I have clear goals"
            case .vision: return "e.g., leading a team I believe in"
            case .communicationStyle: return "e.g., direct and concise"
            case .emotionalBaseline: return "e.g., generally optimistic but anxious under pressure"
            }
        }
    }

    private var isMultiline: Bool {
        switch editItem.type {
        case .situation, .discoveryField:
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

private struct ContextEditorInputSurfaceModifier: ViewModifier {
    let colorScheme: ColorScheme

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
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.22), lineWidth: 0.8)
                )
                .clipShape(shape)
        }
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
