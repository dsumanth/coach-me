//
//  VoiceInputError.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import Foundation

/// Voice input errors with warm, first-person messages
/// Per architecture.md: Warm error messages (UX-11)
enum VoiceInputError: LocalizedError, Equatable {
    case permissionDenied
    case microphonePermissionDenied
    case notAvailable
    case recognitionFailed(Error)
    case audioSessionFailed
    case networkUnavailable
    case noSpeechDetected

    // MARK: - Equatable

    static func == (lhs: VoiceInputError, rhs: VoiceInputError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied):
            return true
        case (.microphonePermissionDenied, .microphonePermissionDenied):
            return true
        case (.notAvailable, .notAvailable):
            return true
        case (.recognitionFailed, .recognitionFailed):
            return true  // Compare by case only, not underlying error
        case (.audioSessionFailed, .audioSessionFailed):
            return true
        case (.networkUnavailable, .networkUnavailable):
            return true
        case (.noSpeechDetected, .noSpeechDetected):
            return true
        default:
            return false
        }
    }

    // MARK: - Error Description

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "I need speech recognition access to understand your voice. You can enable it in Settings."
        case .microphonePermissionDenied:
            return "I need microphone access to hear you. You can enable it in Settings."
        case .notAvailable:
            return "Voice input isn't available on this device."
        case .recognitionFailed:
            return "I couldn't catch that — try again or type instead."
        case .audioSessionFailed:
            return "I had trouble setting up the microphone. Let's try again."
        case .networkUnavailable:
            return "I need an internet connection to understand your voice. Let's try again when you're back online."
        case .noSpeechDetected:
            return "I didn't hear anything — try speaking again or type instead."
        }
    }
}
