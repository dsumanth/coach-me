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
    @Environment(\.colorScheme) private var colorScheme

    /// Network connectivity state (Story 7.2)
    var networkMonitor: NetworkMonitor = .shared

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
                        .foregroundStyle(accessoryIconColor)
                }
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(accessoryFillColor)
                )
                .overlay(
                    Circle()
                        .stroke(accessoryStrokeColor, lineWidth: 1)
                )
                .accessibilityLabel("Add attachment")

                // iMessage-style text input container
                HStack(spacing: 8) {
                    // Text input
                    TextField(
                        "",
                        text: inputTextBinding,
                        prompt: Text("Message your coach...")
                            .foregroundStyle(inputPlaceholderColor),
                        axis: .vertical
                    )
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundColor(inputTextColor)
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
                            isDisabled: viewModel.isLoading || viewModel.isStreaming || !networkMonitor.isConnected,
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
                .modifier(ChatInputSurfaceModifier(colorScheme: colorScheme))
                .frame(minHeight: 44)

                // Send button - only show when there's text (like iMessage)
                if hasText {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canSend ? Color.accentColor : Color(.systemGray3))
                    }
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
                    .accessibilityHint(
                        !networkMonitor.isConnected ? "You're offline. Sending requires a connection." :
                        canSend ? "Sends your message to the coach" : "Type a message first"
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
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
    /// Story 7.2: Also checks network connectivity — can't send when offline
    /// Story 10.1: Also checks rate limit — can't send when rate limited
    private var canSend: Bool {
        let textToCheck = voiceViewModel.transcribedText.isEmpty
            ? viewModel.inputText
            : voiceViewModel.transcribedText
        return !textToCheck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !viewModel.isLoading &&
               !voiceViewModel.isRecording &&
               !viewModel.isRateLimited &&
               networkMonitor.isConnected
    }

    private var inputTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.95) : Color.warmGray900
    }

    private var inputPlaceholderColor: Color {
        colorScheme == .dark ? .white.opacity(0.55) : Color.warmGray500.opacity(0.92)
    }

    private var accessoryFillColor: Color {
        colorScheme == .dark ? Color.warmGray700.opacity(0.78) : Color.white.opacity(0.92)
    }

    private var accessoryStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)
    }

    private var accessoryIconColor: Color {
        colorScheme == .dark ? .white.opacity(0.78) : Color.warmGray600
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

private struct ChatInputSurfaceModifier: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
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
