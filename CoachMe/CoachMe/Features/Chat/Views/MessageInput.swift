//
//  MessageInput.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import SwiftUI
import UIKit

/// Message input area with iMessage-style text field design
struct MessageInput: View {
    @Bindable var viewModel: ChatViewModel
    @Bindable var voiceViewModel: VoiceInputViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Recording indicator - shows when actively recording
            if voiceViewModel.isRecording {
                RecordingIndicator(isRecording: voiceViewModel.isRecording)
                    .transition(.opacity.combined(with: .scale))
            }

            HStack(spacing: 8) {
                // Plus button (like iMessage)
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(.systemGray))
                }
                .frame(width: 32, height: 32)
                .accessibilityLabel("Add attachment")

                // iMessage-style text input container
                HStack(spacing: 8) {
                    // Text input
                    TextField("Message your coach...", text: inputTextBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .tint(.accentColor)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                        .accessibilityLabel("Message input")
                        .accessibilityHint("Type your message to the coach")

                    // Voice input button inside the text field (like iMessage)
                    // Keep visible while recording so gesture can complete
                    if !hasText || voiceViewModel.isRecording {
                        VoiceInputButton(
                            isRecording: voiceViewModel.isRecording,
                            isDisabled: viewModel.isLoading || viewModel.isStreaming,
                            onPress: {
                                Task {
                                    await voiceViewModel.startRecording()
                                }
                            },
                            onRelease: {
                                Task {
                                    await voiceViewModel.stopRecording()
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )

                // Send button - only show when there's text (like iMessage)
                if hasText {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canSend ? Color.accentColor : Color(.systemGray3))
                    }
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
                    .accessibilityHint(canSend ? "Sends your message to the coach" : "Type a message first")
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: voiceViewModel.isRecording)
        .animation(.easeInOut(duration: 0.15), value: hasText)
    }

    // MARK: - Computed Properties

    /// Whether there's any text in the input
    private var hasText: Bool {
        let textToCheck = voiceViewModel.transcribedText.isEmpty
            ? viewModel.inputText
            : voiceViewModel.transcribedText
        return !textToCheck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Binding that syncs voice transcription with input text
    /// Fix for code review M3: Clearer, symmetric get/set behavior
    private var inputTextBinding: Binding<String> {
        Binding(
            get: {
                // During recording, show voice transcription in real-time
                if voiceViewModel.isRecording {
                    return voiceViewModel.transcribedText
                }
                // After recording, show voice transcription for review until user edits
                if !voiceViewModel.transcribedText.isEmpty {
                    return voiceViewModel.transcribedText
                }
                // Otherwise show regular input text
                return viewModel.inputText
            },
            set: { newValue in
                // During recording, ignore manual edits (text is read-only during recording)
                guard !voiceViewModel.isRecording else { return }

                // If voice transcription exists, user is editing it
                // Transfer to inputText and clear voice transcription
                if !voiceViewModel.transcribedText.isEmpty {
                    voiceViewModel.clearTranscript()
                }
                viewModel.inputText = newValue
            }
        )
    }

    /// Whether the send button should be enabled
    private var canSend: Bool {
        let textToCheck = voiceViewModel.transcribedText.isEmpty
            ? viewModel.inputText
            : voiceViewModel.transcribedText
        return !textToCheck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !viewModel.isLoading &&
               !voiceViewModel.isRecording
    }

    // MARK: - Actions

    /// Sends the current message with haptic feedback
    private func sendMessage() {
        guard canSend else { return }

        // Use voice transcription if available
        if !voiceViewModel.transcribedText.isEmpty {
            viewModel.inputText = voiceViewModel.transcribedText
            voiceViewModel.clearTranscript()
        }

        // Haptic feedback on send
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        Task {
            await viewModel.sendMessage()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.cream.ignoresSafeArea()

        VStack {
            Spacer()
            MessageInput(
                viewModel: ChatViewModel(),
                voiceViewModel: VoiceInputViewModel()
            )
        }
    }
}
