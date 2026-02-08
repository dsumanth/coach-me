//
//  CrisisResourceSheet.swift
//  CoachMe
//
//  Story 4.2: Crisis Resource Display
//  Target emotion: "Held, not handled."
//  Presents crisis support resources with empathy when crisis indicators are detected.
//
//  Anti-patterns avoided:
//  - NO system alert / UIAlertController
//  - NO undismissable modal
//  - NO red/warning colors
//  - NO clinical/system language
//  - NO raw .glassEffect() — uses adaptive patterns
//

import SwiftUI

/// Empathetic crisis resource sheet displayed when crisis indicators are detected.
/// Uses warm peach-orange tones, NOT red/error colors.
struct CrisisResourceSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Empathetic header
                headerSection

                // Resource intro
                Text("You can reach out to:")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                // Resource cards
                ForEach(CrisisResource.allResources) { resource in
                    resourceCard(resource)
                }

                // Gentle close
                closeSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(Color.adaptiveCrisisSurface(colorScheme).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I hear you, and what you're feeling sounds really heavy.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.adaptiveCrisisAccent(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("This is beyond what I can help with as a coaching tool, but there are people who can help right now.")
                .font(.body)
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Resource Card

    private func resourceCard(_ resource: CrisisResource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.name)
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveCrisisAccent(colorScheme))

                    Text(resource.description)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
                }

                Spacer()

                Text(resource.availability)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.adaptiveCrisisAccent(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.adaptiveCrisisAccent(colorScheme).opacity(0.12))
                    )
            }

            // Action buttons
            HStack(spacing: 12) {
                if let phoneURL = resource.phoneURL {
                    actionButton(
                        title: "Call \(resource.phoneNumber ?? "")",
                        icon: "phone.fill",
                        accessibilityLabel: "Call \(resource.name)",
                        accessibilityHint: "Opens phone to call \(resource.phoneNumber ?? ""), available \(resource.availability)"
                    ) {
                        openURL(phoneURL)
                    }
                }

                if let smsURL = resource.smsURL {
                    let bodyDescription = resource.textBody.map { " \($0)" } ?? ""
                    actionButton(
                        title: "Text\(bodyDescription) to \(resource.textNumber ?? "")",
                        icon: "message.fill",
                        accessibilityLabel: "Text \(resource.name)",
                        accessibilityHint: "Opens Messages to text\(bodyDescription) to \(resource.textNumber ?? ""), available \(resource.availability)"
                    ) {
                        openURL(smsURL)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Action Button

    private func actionButton(
        title: String,
        icon: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44) // HIG minimum touch target
            .background(
                Capsule()
                    .fill(Color.adaptiveCrisisAccent(colorScheme))
            )
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Close Section

    private var closeSection: some View {
        Text("I'm here for coaching when you're ready to come back.")
            .font(.subheadline)
            .foregroundStyle(Color.adaptiveText(colorScheme, isPrimary: false))
            .italic()
            .padding(.top, 4)
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        Group {
            if #available(iOS 26, *) {
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
                    .overlay(
                        shape
                            .fill(
                                colorScheme == .dark
                                    ? Color.black.opacity(0.2)
                                    : Color.white.opacity(0.6)
                            )
                    )
                    .overlay(
                        shape.stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.14)
                                : Color.white.opacity(0.5),
                            lineWidth: 1
                        )
                    )
                    .clipShape(shape)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? Color.surfaceLightDark.opacity(0.9)
                            : Color.white.opacity(0.75)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview("Crisis Resource Sheet - Light") {
    Text("Chat content")
        .sheet(isPresented: .constant(true)) {
            CrisisResourceSheet()
        }
}

#Preview("Crisis Resource Sheet - Dark") {
    Text("Chat content")
        .preferredColorScheme(.dark)
        .sheet(isPresented: .constant(true)) {
            CrisisResourceSheet()
        }
}
