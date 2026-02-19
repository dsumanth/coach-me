//
//  UsageIndicator.swift
//  CoachMe
//
//  Story 10.5: Usage Transparency UI
//  Non-intrusive banner showing message usage status in ChatView
//

import SwiftUI

/// A warm, non-intrusive indicator for message usage.
/// Matches the OfflineBanner and TrialBanner styling patterns.
struct UsageIndicator: View {
    let viewModel: UsageViewModel
    @Binding var showDetail: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch viewModel.displayState {
        case .hidden:
            EmptyView()

        case .compact(let remaining, let tier):
            bannerContent(
                icon: tier == .prominent ? "exclamationmark.circle" : "chart.bar",
                accentColor: tier == .prominent ? Color.orange : Color.terracotta,
                title: tier == .prominent
                    ? prominentTitle(remaining: remaining)
                    : "You have \(remaining) conversations left this month",
                subtitle: nil
            )

        case .trial(let remaining, let total):
            bannerContent(
                icon: "sparkles",
                accentColor: Color.terracotta,
                title: "\(remaining) of \(total) trial messages remaining",
                subtitle: nil
            )

        case .blocked(let resetDate):
            blockedContent(resetDate: resetDate)
        }
    }

    // MARK: - Prominent Title

    private func prominentTitle(remaining: Int) -> String {
        if viewModel.currentUsage != nil {
            let resetDate = nextResetDateString()
            return "Almost there — \(remaining) messages left until \(resetDate)"
        }
        return "Almost there — \(remaining) messages left"
    }

    // MARK: - Banner Content

    private func bannerContent(
        icon: String,
        accentColor: Color,
        title: String,
        subtitle: String?
    ) -> some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(accentColor.opacity(0.14))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .adaptiveGlass()
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.accessibleUsageDescription)
        .accessibilityHint("Tap for usage details")
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Blocked Content

    private func blockedContent(resetDate: Date?) -> some View {
        let isTrial = isTrial()

        return Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.orange.opacity(0.14))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    if isTrial {
                        Text("You've used your trial sessions — ready to continue?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let date = resetDate {
                        Text("We've had a lot of great conversations this month! Your next session refreshes on \(formattedDate(date)).")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("We've had a lot of great conversations this month!")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .adaptiveGlass()
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.accessibleUsageDescription)
        .accessibilityHint("Tap for usage details")
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func isTrial() -> Bool {
        if case .paidTrial = AppEnvironment.shared.subscriptionViewModel.state {
            return true
        }
        return false
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func nextResetDateString() -> String {
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date()) {
            let components = calendar.dateComponents([.year, .month], from: nextMonth)
            if let resetDate = calendar.date(from: components) {
                return formattedDate(resetDate)
            }
        }
        return "next month"
    }
}
