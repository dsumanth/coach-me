//
//  SubscriptionManagementState.swift
//  CoachMe
//
//  Story 6.4: Subscription Management — state enum for management view
//

import SwiftUI

/// Represents the user's subscription status as displayed in the management view.
/// Separate from `SubscriptionState` (trial lifecycle) in SubscriptionViewModel.
enum SubscriptionManagementState: String, CaseIterable {
    case active
    case cancelled
    case billingIssue
    case expired
    case free

    var displayLabel: String {
        switch self {
        case .active: "Active"
        case .cancelled: "Cancelled"
        case .billingIssue: "Billing Issue"
        case .expired: "Expired"
        case .free: "Free"
        }
    }

    var statusColor: Color {
        switch self {
        case .active: .green
        case .cancelled: .orange
        case .billingIssue: .red
        case .expired, .free: .secondary
        }
    }

    var systemImageName: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        case .billingIssue: "exclamationmark.triangle.fill"
        case .expired: "clock.arrow.circlepath"
        case .free: "person.crop.circle"
        }
    }
}
