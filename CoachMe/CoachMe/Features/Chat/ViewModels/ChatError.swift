//
//  ChatError.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import Foundation

/// Chat-specific errors with warm, first-person messages (UX-11)
/// Per architecture.md: Warm, first-person error messages
enum ChatError: LocalizedError, Equatable {
    case messageFailed(Error)
    case networkUnavailable
    case sessionExpired
    case streamError(String)
    case streamInterrupted

    var errorDescription: String? {
        switch self {
        case .messageFailed:
            return "Coach is taking a moment. Let's try again."
        case .networkUnavailable:
            return "I couldn't connect right now. Let's try again when you're back online."
        case .sessionExpired:
            return "I had trouble remembering you. Please sign in again."
        case .streamError(let message):
            return message
        case .streamInterrupted:
            return "Our conversation was interrupted. Tap retry to continue."
        }
    }

    static func == (lhs: ChatError, rhs: ChatError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}
