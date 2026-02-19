//
//  PersonalizedPaywallViewModel.swift
//  CoachMe
//
//  Story 11.5: Personalized Paywall — ViewModel and types
//

import Foundation

// MARK: - DiscoveryPaywallContext (Task 1.3)

/// Lightweight DTO containing discovery-extracted fields for paywall copy generation.
/// Decoupled from ContextProfile — only carries the 3-4 fields the paywall needs.
struct DiscoveryPaywallContext: Equatable, Sendable {
    let coachingDomain: String?
    let ahaInsight: String?
    let keyTheme: String?
    let userName: String?
}

// MARK: - PaywallPresentation (Task 1.2)

/// Controls how the personalized paywall is presented.
enum PaywallPresentation: Equatable {
    /// Overlay on chat — coach's last message visible behind material blur.
    /// Used immediately after discovery completes.
    case firstPresentation(discoveryContext: DiscoveryPaywallContext)

    /// Full-screen sheet — no chat context behind it.
    /// Used when user returns after dismissing the first presentation.
    case returnPresentation(discoveryContext: DiscoveryPaywallContext?)
}

// MARK: - PersonalizedPaywallViewModel (Task 2)

/// Generates personalized paywall copy from discovery context.
/// Copy is built client-side from extracted context fields.
@MainActor
@Observable
final class PersonalizedPaywallViewModel {
    // MARK: - Properties (Task 2.2)

    let presentation: PaywallPresentation

    /// Task 2.6: Track impression to log once per presentation
    var impressionLogged = false

    // MARK: - Initialization

    init(presentation: PaywallPresentation) {
        self.presentation = presentation
    }

    // MARK: - Computed Properties (Task 2.3)

    var discoveryContext: DiscoveryPaywallContext {
        switch presentation {
        case .firstPresentation(let context):
            return context
        case .returnPresentation(let context):
            return context ?? DiscoveryPaywallContext(coachingDomain: nil, ahaInsight: nil, keyTheme: nil, userName: nil)
        }
    }

    /// Dynamic header text based on discovery context and presentation mode (Task 2.4)
    var headerText: String {
        isFirstPresentation ? buildHeaderText() : returnHeaderText
    }

    /// Dynamic body text based on discovery context (Task 2.5)
    var bodyText: String {
        buildBodyText()
    }

    /// CTA text — always the same warm phrasing
    var ctaText: String {
        "Continue my coaching journey"
    }

    /// Whether this is the first presentation (overlay) or return (sheet)
    var isFirstPresentation: Bool {
        if case .firstPresentation = presentation { return true }
        return false
    }

    // MARK: - Copy Generation (Tasks 2.4, 2.5)

    /// Builds personalized header. Uses coaching domain when available, falls back to generic.
    func buildHeaderText() -> String {
        if let domain = discoveryContext.coachingDomain, !domain.isEmpty {
            return "Your coach understands your \(domain). Ready to keep going?"
        }
        return "Your coach gets you. Ready for more?"
    }

    /// Builds personalized body. Checks aha insight first, then key theme, then fallback.
    func buildBodyText() -> String {
        if let insight = discoveryContext.ahaInsight, !insight.isEmpty {
            return "You've already taken the hardest step — getting honest about \(insight). Let's keep building on that."
        }
        if let theme = discoveryContext.keyTheme, !theme.isEmpty {
            return "You've already taken the hardest step — getting honest about \(theme). Let's keep building on that."
        }
        return "You've already started something meaningful. Let's keep going."
    }

    /// Return-variant header for when user comes back after dismissing
    var returnHeaderText: String {
        "Your coach is still here. Pick up where you left off."
    }
}
