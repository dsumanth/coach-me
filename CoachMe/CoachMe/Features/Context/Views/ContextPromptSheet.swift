//
//  ContextPromptSheet.swift
//  CoachMe
//
//  Story 2.2: Context Setup Prompt After First Session
//  Per architecture.md: Use adaptive design modifiers, VoiceOver accessibility
//  Per UX-8: "Want me to remember what matters to you?"
//

import SwiftUI

/// Sheet that asks users if they want the coach to remember their context
/// Displayed after the first AI response in a coaching session
/// Per UX-8: Warm, inviting tone that feels like a natural pause
struct ContextPromptSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Actions

    /// Called when user taps "Yes, remember me"
    let onAccept: () -> Void

    /// Called when user taps "Not now"
    let onDismiss: () -> Void

    /// Called when user taps close button
    let onClose: () -> Void

    // MARK: - Body

    var body: some View {
        sheetPanel
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Context setup prompt")
    }

    private var sheetPanel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(colorScheme == .dark ? .white.opacity(0.55) : Color.warmGray400.opacity(0.8))
                .frame(width: 56, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 4)

            HStack {
                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : Color.warmGray700)
                        .frame(width: 44, height: 44)
                        .modifier(LiquidCircleControlModifier(colorScheme: colorScheme))
                }
                .accessibilityLabel("Close")
                .accessibilityHint("Dismisses this prompt")
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            VStack(spacing: 20) {
                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.adaptiveTerracotta(colorScheme))
                    .padding(.top, 4)
                    .accessibilityHidden(true)

                Text("Want me to remember what matters to you?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("I can coach you better when I know what matters most to you.")
                    .font(.body)
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                VStack(spacing: 12) {
                    Button(action: onAccept) {
                        Text("Yes, remember me")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(Color.terracotta)
                            )
                    }
                    .accessibilityLabel("Yes, remember me")
                    .accessibilityHint("Opens context setup to personalize your coaching")

                    Button(action: onDismiss) {
                        Text("Not now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.95) : Color.warmGray700)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .modifier(LiquidSecondaryButtonModifier(colorScheme: colorScheme))
                    }
                    .accessibilityLabel("Not now")
                    .accessibilityHint("Dismisses this prompt. I can ask again later.")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .modifier(LiquidPanelModifier(colorScheme: colorScheme))
    }

    private var primaryTextColor: Color {
        Color.adaptiveText(colorScheme)
    }

    private var secondaryTextColor: Color {
        Color.adaptiveText(colorScheme, isPrimary: false)
    }
}

private struct LiquidPanelModifier: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        if #available(iOS 26, *) {
            content
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.36)
                                : Color.white.opacity(0.78)
                        )
                }
                .overlay(
                    shape
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.2)
                                : Color.white.opacity(0.46),
                            lineWidth: 1
                        )
                )
                .clipShape(shape)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        } else {
            content
                .background(
                    shape.fill(
                        colorScheme == .dark
                            ? Color.warmGray800.opacity(0.94)
                            : Color.warmGray50.opacity(0.98)
                    )
                )
                .overlay(
                    shape
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.16)
                                : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        }
    }
}

private struct LiquidCircleControlModifier: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        let shape = Circle()
        if #available(iOS 26, *) {
            content
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(0.03)
                                : Color.white.opacity(0.55)
                        )
                }
                .overlay(
                    shape.stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.2)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
                )
                .clipShape(shape)
        } else {
            content
                .background(
                    shape.fill(
                        colorScheme == .dark
                            ? .white.opacity(0.18)
                            : Color.warmGray100.opacity(0.95)
                    )
                )
                .clipShape(shape)
        }
    }
}

private struct LiquidSecondaryButtonModifier: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if #available(iOS 26, *) {
            content
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(0.03)
                                : Color.white.opacity(0.42)
                        )
                }
                .overlay(
                    shape.stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.2)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
                )
                .clipShape(shape)
        } else {
            content
                .background(
                    shape.fill(
                        colorScheme == .dark
                            ? .white.opacity(0.2)
                            : Color.warmGray100.opacity(0.9)
                    )
                )
                .clipShape(shape)
        }
    }
}

// MARK: - Preview

#Preview("ContextPromptSheet") {
    ContextPromptSheet(
        onAccept: { print("Accepted") },
        onDismiss: { print("Dismissed") },
        onClose: { print("Closed") }
    )
}

#Preview("ContextPromptSheet - Dark") {
    ContextPromptSheet(
        onAccept: { print("Accepted") },
        onDismiss: { print("Dismissed") },
        onClose: { print("Closed") }
    )
    .preferredColorScheme(.dark)
}
