//
//  TrialBanner.swift
//  CoachMe
//
//  Story 6.2: Free Trial Experience — Trial status banner for ChatView
//  Story 10.3: Updated to read from TrialManager for paid trial status
//  Story 10.4: Last-day emphasis, low-messages emphasis, VoiceOver improvements
//

import SwiftUI

/// A gentle banner showing trial status with warm, first-person messaging.
/// Story 10.4: Enhanced with last-day emphasis (amber accent) and low-messages bold weight.
struct TrialBanner: View {
    let onViewPlans: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var trialManager: TrialManager { TrialManager.shared }

    /// Story 10.4: Whether this is the last day of the trial
    private var isLastDay: Bool {
        trialManager.trialDayNumber >= TrialManager.trialDurationDays ||
        (trialManager.trialTimeRemaining > 0 && trialManager.trialTimeRemaining <= 24 * 60 * 60)
    }

    /// Story 10.4: Whether messages are running low (<=10 remaining)
    private var isLowMessages: Bool {
        trialManager.messagesRemaining <= 10 && trialManager.messagesRemaining > 0
    }

    /// Story 10.4: Accent color — warm amber on last day, terracotta otherwise
    private var accentColor: Color {
        isLastDay ? Color.orange : Color.terracotta
    }

    var body: some View {
        HStack(spacing: 12) {
            // Trial icon
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(accentColor.opacity(0.14))
                )
                .accessibilityHidden(true)

            // Trial message
            VStack(alignment: .leading, spacing: 2) {
                if isLastDay {
                    // Last-day emphasis copy
                    Text("Last day of your 3-day access — subscribe to keep the conversation going.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Story 10.4 — Task 3.2: Normal trial display
                    trialStatusText
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            // Gentle CTA — not aggressive
            Button("See plans") {
                onViewPlans()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.13))
            )
            .accessibilityHint("View available subscription options")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .adaptiveGlass()
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        // Story 10.4 — Task 3.6: VoiceOver label includes both days and messages
        .accessibilityLabel(accessibilityStatusLabel)
    }

    // MARK: - Story 10.4: Trial Status Text with Low-Messages Emphasis

    /// Builds the trial status text, bolding the message count when low (<=10)
    private var trialStatusText: Text {
        let dayPart = "Day \(trialManager.trialDayNumber) of \(TrialManager.trialDurationDays) — "
        let msgCount = "\(trialManager.messagesRemaining)"
        let msgSuffix = " conversations left"

        if isLowMessages {
            // Story 10.4 — Task 3.4: Bold message count when <=10
            return Text(dayPart) + Text(msgCount).bold() + Text(msgSuffix)
        } else {
            return Text(dayPart + msgCount + msgSuffix)
        }
    }

    // MARK: - Accessibility

    /// Story 10.4 — Task 3.6: Full VoiceOver label with days and messages
    private var accessibilityStatusLabel: String {
        let day = trialManager.trialDayNumber
        let total = TrialManager.trialDurationDays
        let msgs = trialManager.messagesRemaining

        if isLastDay {
            return "Trial status: Last day of your 3-day access. \(msgs) conversations remaining. Subscribe to keep the conversation going."
        }
        return "Trial status: Day \(day) of \(total). \(msgs) conversations remaining."
    }
}
