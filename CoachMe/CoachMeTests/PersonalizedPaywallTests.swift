//
//  PersonalizedPaywallTests.swift
//  CoachMeTests
//
//  Story 11.5 — Task 7: PersonalizedPaywallViewModel, ChatViewModel paywall flow,
//  DiscoveryPaywallContext SSE construction, and OnboardingCoordinator persistence tests
//

import Testing
import Foundation
@testable import CoachMe

@MainActor
struct PersonalizedPaywallTests {

    // MARK: - Setup

    private func cleanUp() {
        OnboardingCoordinator.clearPersistedState()
    }

    // MARK: - Task 7.1: PersonalizedPaywallViewModel Copy Generation

    @Test("Header text uses coaching domain when available")
    func testHeaderTextWithDomain() {
        let context = DiscoveryPaywallContext(
            coachingDomain: "career transitions",
            ahaInsight: nil,
            keyTheme: nil,
            userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.headerText.contains("career transitions"))
        #expect(vm.headerText.contains("Ready to keep going"))
    }

    @Test("Header text falls back to generic when no domain")
    func testHeaderTextFallback() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil,
            ahaInsight: nil,
            keyTheme: nil,
            userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.headerText == "Your coach gets you. Ready for more?")
    }

    @Test("Header text falls back when domain is empty string")
    func testHeaderTextEmptyDomainFallback() {
        let context = DiscoveryPaywallContext(
            coachingDomain: "",
            ahaInsight: nil,
            keyTheme: nil,
            userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.headerText == "Your coach gets you. Ready for more?")
    }

    @Test("Body text uses aha insight when available")
    func testBodyTextWithInsight() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil,
            ahaInsight: "fear of failure",
            keyTheme: nil,
            userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.bodyText.contains("fear of failure"))
        #expect(vm.bodyText.contains("getting honest about"))
    }

    @Test("Body text uses key theme when no aha insight")
    func testBodyTextWithTheme() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil,
            ahaInsight: nil,
            keyTheme: "work-life balance",
            userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.bodyText.contains("work-life balance"))
    }

    @Test("Body text falls back when no insight or theme")
    func testBodyTextFallback() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil,
            ahaInsight: nil,
            keyTheme: nil,
            userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.bodyText == "You've already started something meaningful. Let's keep going.")
    }

    @Test("Body text prefers aha insight over key theme")
    func testBodyTextPrefersInsight() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil,
            ahaInsight: "perfectionism",
            keyTheme: "leadership",
            userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.bodyText.contains("perfectionism"))
        #expect(!vm.bodyText.contains("leadership"))
    }

    // MARK: - Task 7.2: Presentation Mode Tests

    @Test("isFirstPresentation returns true for firstPresentation")
    func testIsFirstPresentation() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil, ahaInsight: nil, keyTheme: nil, userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.isFirstPresentation == true)
    }

    @Test("isFirstPresentation returns false for returnPresentation")
    func testIsNotFirstPresentation() {
        let vm = PersonalizedPaywallViewModel(
            presentation: .returnPresentation(discoveryContext: nil)
        )

        #expect(vm.isFirstPresentation == false)
    }

    @Test("CTA text is consistent")
    func testCTAText() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil, ahaInsight: nil, keyTheme: nil, userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.ctaText == "Continue my coaching journey")
    }

    @Test("Return header text is warm re-engagement copy")
    func testReturnHeaderText() {
        let vm = PersonalizedPaywallViewModel(
            presentation: .returnPresentation(discoveryContext: nil)
        )

        #expect(vm.returnHeaderText == "Your coach is still here. Pick up where you left off.")
    }

    @Test("Return presentation with nil context uses empty defaults")
    func testReturnPresentationNilContext() {
        let vm = PersonalizedPaywallViewModel(
            presentation: .returnPresentation(discoveryContext: nil)
        )

        #expect(vm.discoveryContext.coachingDomain == nil)
        #expect(vm.discoveryContext.ahaInsight == nil)
        #expect(vm.headerText == "Your coach gets you. Ready for more?")
    }

    @Test("Return presentation preserves discovery context")
    func testReturnPresentationPreservesContext() {
        let context = DiscoveryPaywallContext(
            coachingDomain: "relationships",
            ahaInsight: "vulnerability",
            keyTheme: nil,
            userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .returnPresentation(discoveryContext: context)
        )

        #expect(vm.discoveryContext.coachingDomain == "relationships")
        #expect(vm.headerText.contains("relationships"))
    }

    // MARK: - Task 7.3: ChatViewModel Discovery Paywall Flow

    @Test("ChatViewModel discoveryPaywallContext defaults to nil")
    func testDefaultDiscoveryPaywallContext() {
        let vm = ChatViewModel()
        #expect(vm.discoveryPaywallContext == nil)
        #expect(vm.discoveryPaywallDismissed == false)
    }

    @Test("ChatViewModel showPersonalizedPaywall is false by default")
    func testShowPersonalizedPaywallDefault() {
        let vm = ChatViewModel()
        #expect(vm.showPersonalizedPaywall == false)
    }

    @Test("ChatViewModel discoveryPaywallDismissed resets on new conversation")
    func testDiscoveryPaywallDismissedResetsOnNewConversation() {
        let vm = ChatViewModel()
        vm.discoveryPaywallDismissed = true
        vm.discoveryPaywallContext = DiscoveryPaywallContext(
            coachingDomain: "test", ahaInsight: nil, keyTheme: nil, userName: nil
        )

        vm.startNewConversation()

        #expect(vm.discoveryPaywallDismissed == false)
        #expect(vm.discoveryPaywallContext == nil)
    }

    // MARK: - Task 7.4: DiscoveryPaywallContext Construction from SSE

    @Test("DiscoveryPaywallContext constructed from full profile data")
    func testContextFromFullProfile() {
        let profile = ChatStreamService.StreamEvent.DiscoveryProfileData(
            coachingDomains: ["career", "leadership"],
            ahaInsight: "fear of conflict",
            keyThemes: ["communication", "boundaries"]
        )

        let context = DiscoveryPaywallContext(
            coachingDomain: profile.coachingDomains?.first,
            ahaInsight: profile.ahaInsight,
            keyTheme: profile.keyThemes?.first,
            userName: nil
        )

        #expect(context.coachingDomain == "career")
        #expect(context.ahaInsight == "fear of conflict")
        #expect(context.keyTheme == "communication")
    }

    @Test("DiscoveryPaywallContext constructed from partial profile data")
    func testContextFromPartialProfile() {
        let profile = ChatStreamService.StreamEvent.DiscoveryProfileData(
            coachingDomains: nil,
            ahaInsight: "procrastination",
            keyThemes: nil
        )

        let context = DiscoveryPaywallContext(
            coachingDomain: profile.coachingDomains?.first,
            ahaInsight: profile.ahaInsight,
            keyTheme: profile.keyThemes?.first,
            userName: nil
        )

        #expect(context.coachingDomain == nil)
        #expect(context.ahaInsight == "procrastination")
        #expect(context.keyTheme == nil)
    }

    @Test("DiscoveryPaywallContext constructed from nil profile uses all nils")
    func testContextFromNilProfile() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil,
            ahaInsight: nil,
            keyTheme: nil,
            userName: nil
        )

        #expect(context.coachingDomain == nil)
        #expect(context.ahaInsight == nil)
        #expect(context.keyTheme == nil)
        #expect(context.userName == nil)
    }

    @Test("StreamEvent done event with discovery_profile decodes correctly")
    func testDoneEventWithDiscoveryProfile() throws {
        let json = """
        {"type":"done","message_id":"550e8400-e29b-41d4-a716-446655440000","usage":{"prompt_tokens":10,"completion_tokens":20,"total_tokens":30},"discovery_complete":true,"discovery_profile":{"coaching_domains":["career"],"aha_insight":"fear of failure","key_themes":["leadership"]}}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .done(_, _, _, let discoveryComplete, let profile) = event {
            #expect(discoveryComplete == true)
            #expect(profile?.coachingDomains == ["career"])
            #expect(profile?.ahaInsight == "fear of failure")
            #expect(profile?.keyThemes == ["leadership"])
        } else {
            Issue.record("Expected done event with discovery_profile")
        }
    }

    @Test("StreamEvent done event without discovery_profile decodes with nil profile")
    func testDoneEventWithoutDiscoveryProfile() throws {
        let json = """
        {"type":"done","message_id":"550e8400-e29b-41d4-a716-446655440000","usage":{"prompt_tokens":10,"completion_tokens":20,"total_tokens":30},"discovery_complete":true}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .done(_, _, _, let discoveryComplete, let profile) = event {
            #expect(discoveryComplete == true)
            #expect(profile == nil)
        } else {
            Issue.record("Expected done event without discovery_profile")
        }
    }

    // MARK: - Task 7.5: OnboardingCoordinator Paywall State Persistence

    @Test("OnboardingCoordinator stores discoveryPaywallContext")
    func testCoordinatorStoresContext() {
        cleanUp()
        let coordinator = OnboardingCoordinator()
        let context = DiscoveryPaywallContext(
            coachingDomain: "health",
            ahaInsight: "stress management",
            keyTheme: nil,
            userName: nil
        )

        coordinator.onDiscoveryComplete(with: context)

        #expect(coordinator.discoveryPaywallContext?.coachingDomain == "health")
        #expect(coordinator.discoveryPaywallContext?.ahaInsight == "stress management")
        #expect(coordinator.flowState == .paywall)
        #expect(coordinator.discoveryCompleted == true)
        cleanUp()
    }

    @Test("OnboardingCoordinator shouldShowReturnPaywall is true after discovery without subscription")
    func testShouldShowReturnPaywall() {
        cleanUp()
        let coordinator = OnboardingCoordinator()
        coordinator.beginDiscovery()
        coordinator.onDiscoveryComplete()

        #expect(coordinator.shouldShowReturnPaywall == true)
        cleanUp()
    }

    @Test("OnboardingCoordinator shouldShowReturnPaywall is false after subscription")
    func testShouldNotShowReturnPaywallAfterSubscription() {
        cleanUp()
        let coordinator = OnboardingCoordinator()
        coordinator.beginDiscovery()
        coordinator.onDiscoveryComplete()
        coordinator.onSubscriptionConfirmed()

        #expect(coordinator.shouldShowReturnPaywall == false)
        cleanUp()
    }

    @Test("OnboardingCoordinator reset clears discoveryPaywallContext")
    func testResetClearsContext() {
        cleanUp()
        let coordinator = OnboardingCoordinator()
        coordinator.discoveryPaywallContext = DiscoveryPaywallContext(
            coachingDomain: "test",
            ahaInsight: nil,
            keyTheme: nil,
            userName: nil
        )

        coordinator.reset()

        #expect(coordinator.discoveryPaywallContext == nil)
        #expect(coordinator.flowState == .welcome)
        cleanUp()
    }

    // MARK: - M2 fix: OnboardingCoordinator State Restoration Tests

    @Test("OnboardingCoordinator restores paywall flow state on init when discovery done but not subscribed")
    func testCoordinatorRestoresPaywallState() {
        cleanUp()
        UserDefaults.standard.set(true, forKey: "discovery_completed")
        UserDefaults.standard.set(false, forKey: "has_completed_onboarding")

        let coordinator = OnboardingCoordinator()

        #expect(coordinator.flowState == .paywall)
        #expect(coordinator.shouldShowReturnPaywall == true)
        cleanUp()
    }

    @Test("OnboardingCoordinator does NOT restore paywall state when onboarding complete")
    func testCoordinatorDoesNotRestoreWhenComplete() {
        cleanUp()
        UserDefaults.standard.set(true, forKey: "discovery_completed")
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")

        let coordinator = OnboardingCoordinator()

        #expect(coordinator.flowState == .welcome)
        #expect(coordinator.shouldShowReturnPaywall == false)
        cleanUp()
    }

    @Test("OnboardingCoordinator defaults to welcome when no persisted state")
    func testCoordinatorDefaultsToWelcome() {
        cleanUp()
        let coordinator = OnboardingCoordinator()

        #expect(coordinator.flowState == .welcome)
        #expect(coordinator.shouldShowReturnPaywall == false)
        cleanUp()
    }

    @Test("PersonalizedPaywallViewModel impressionLogged starts false")
    func testImpressionLoggedDefault() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil, ahaInsight: nil, keyTheme: nil, userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )

        #expect(vm.impressionLogged == false)
    }

    @Test("PersonalizedPaywallViewModel impressionLogged can be set to true")
    func testImpressionLoggedTracking() {
        let context = DiscoveryPaywallContext(
            coachingDomain: nil, ahaInsight: nil, keyTheme: nil, userName: nil
        )
        let vm = PersonalizedPaywallViewModel(
            presentation: .firstPresentation(discoveryContext: context)
        )
        vm.impressionLogged = true

        #expect(vm.impressionLogged == true)
    }

    // MARK: - DiscoveryPaywallContext Equatable

    @Test("DiscoveryPaywallContext equatable works correctly")
    func testContextEquatable() {
        let a = DiscoveryPaywallContext(
            coachingDomain: "career",
            ahaInsight: "clarity",
            keyTheme: "growth",
            userName: "Alex"
        )
        let b = DiscoveryPaywallContext(
            coachingDomain: "career",
            ahaInsight: "clarity",
            keyTheme: "growth",
            userName: "Alex"
        )
        let c = DiscoveryPaywallContext(
            coachingDomain: nil,
            ahaInsight: nil,
            keyTheme: nil,
            userName: nil
        )

        #expect(a == b)
        #expect(a != c)
    }
}
