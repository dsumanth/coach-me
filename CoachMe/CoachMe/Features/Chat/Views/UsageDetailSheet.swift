//
//  UsageDetailSheet.swift
//  CoachMe
//
//  Story 10.5: Usage Transparency UI
//  Detail sheet showing full usage breakdown with progress bar and subscription link
//

import SwiftUI

/// Detailed usage breakdown sheet presented when tapping the UsageIndicator.
/// Shows messages used/remaining, a progress bar, reset/expiry date, and subscription management link.
struct UsageDetailSheet: View {
    let viewModel: UsageViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSubscriptionManagement = false

    private var subscriptionViewModel: SubscriptionViewModel {
        AppEnvironment.shared.subscriptionViewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveCream(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Tier label
                        tierLabel

                        // Usage card
                        usageCard

                        // Reset/expiry info
                        dateInfoCard

                        // Manage Subscription link
                        manageSubscriptionButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Your Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                }
            }
            .sheet(isPresented: $showSubscriptionManagement) {
                NavigationStack {
                    SubscriptionManagementView()
                }
            }
        }
    }

    // MARK: - Tier Label

    private var tierLabel: some View {
        HStack {
            Text(tierDisplayString)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var tierDisplayString: String {
        switch subscriptionViewModel.state {
        case .paidTrial(_, _):
            let day = TrialManager.shared.trialDayNumber
            let total = TrialManager.trialDurationDays
            return "Trial — Day \(day) of \(total)"
        case .subscribed:
            return "Premium"
        default:
            return "CoachMe"
        }
    }

    // MARK: - Usage Card

    private var usageCard: some View {
        VStack(spacing: 16) {
            if let usage = viewModel.currentUsage {
                // Messages used / remaining counts
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Messages Used")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        Text("\(usage.messageCount)")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(usage.messageCount) messages used")

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                        Text("\(usage.messagesRemaining)")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(usage.messagesRemaining) messages remaining")
                }

                // Progress bar
                usageProgressBar(percentage: usage.usagePercentage)
                    .accessibilityLabel("\(Int(usage.usagePercentage * 100)) percent used")
            } else {
                Text("No usage data available yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            }
        }
        .padding(16)
        .adaptiveGlass()
    }

    // MARK: - Progress Bar

    private func usageProgressBar(percentage: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.adaptiveText(colorScheme, isPrimary: false).opacity(0.12))

                // Fill with warm gradient
                RoundedRectangle(cornerRadius: 6)
                    .fill(progressGradient(percentage: percentage))
                    .frame(width: max(geometry.size.width * percentage, 0))
            }
        }
        .frame(height: 12)
    }

    /// Warm color gradient: green → terracotta → orange based on usage percentage
    private func progressGradient(percentage: Double) -> LinearGradient {
        let color: Color = {
            switch percentage {
            case ..<0.80:
                return .green
            case 0.80..<0.95:
                return .terracotta
            default:
                return .orange
            }
        }()
        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Date Info Card

    private var dateInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                    .accessibilityHidden(true)

                Text(dateInfoString)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .adaptiveGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dateInfoString)
    }

    private var dateInfoString: String {
        switch subscriptionViewModel.state {
        case .paidTrial:
            if let expiryDate = TrialManager.shared.trialExpirationDate {
                return "Trial ends \(formattedDate(expiryDate))"
            }
            return "Trial active"
        case .subscribed:
            // Approximate next reset as first of next month
            let calendar = Calendar.current
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date()) {
                let components = calendar.dateComponents([.year, .month], from: nextMonth)
                if let resetDate = calendar.date(from: components) {
                    return "Usage resets \(formattedDate(resetDate))"
                }
            }
            return "Usage resets next billing cycle"
        default:
            return ""
        }
    }

    // MARK: - Manage Subscription

    private var manageSubscriptionButton: some View {
        Button {
            showSubscriptionManagement = true
        } label: {
            HStack {
                Image(systemName: "crown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                Text("Manage Subscription")
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            }
            .padding(16)
            .adaptiveGlass()
        }
        .accessibilityLabel("Manage Subscription")
        .accessibilityHint("View your plan and subscription details")
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
