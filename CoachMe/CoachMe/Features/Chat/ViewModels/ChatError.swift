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
    /// Story 10.1: User has exceeded their message limit for the billing period
    case rateLimited(isTrial: Bool, resetDate: Date?)

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
        case .rateLimited(let isTrial, let resetDate):
            if isTrial {
                return "You've used your trial sessions — ready to continue?"
            } else {
                let dateStr = resetDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) } ?? "soon"
                return "We've had a lot of great conversations this month! Your next session refreshes on \(dateStr)."
            }
        }
    }

    static func == (lhs: ChatError, rhs: ChatError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}
