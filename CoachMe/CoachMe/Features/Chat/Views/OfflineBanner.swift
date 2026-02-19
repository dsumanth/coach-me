//
//  OfflineBanner.swift
//  CoachMe
//
//  Story 7.2: Offline Warning Banner — Warm, non-alarming connectivity notice
//

import SwiftUI

/// A warm, non-alarming banner shown when the user loses network connectivity.
/// Uses adaptive glass styling: Liquid Glass on iOS 26+, ultraThinMaterial on iOS 18-25.
/// Per UX-10: "Calm, informed" target emotion for offline state.
struct OfflineBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Offline icon — wifi.slash with warm terracotta accent (not alarming red)
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.terracotta)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.terracotta.opacity(0.14))
                )
                .accessibilityHidden(true)

            // Warm offline message per UX-10/UX-11
            VStack(alignment: .leading, spacing: 2) {
                Text("You're offline right now")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("Your past conversations are here — new coaching needs a connection.")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .adaptiveGlass()
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline notice. You're offline right now. Your past conversations are available. New coaching needs a connection.")
    }
}

// MARK: - Preview

#Preview("Offline Banner - Light") {
    ZStack {
        Color.cream.ignoresSafeArea()
        VStack {
            OfflineBanner()
            Spacer()
        }
    }
}

#Preview("Offline Banner - Dark") {
    ZStack {
        Color.creamDark.ignoresSafeArea()
        VStack {
            OfflineBanner()
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
