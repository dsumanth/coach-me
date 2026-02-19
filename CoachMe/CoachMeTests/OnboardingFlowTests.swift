//
//  OnboardingFlowTests.swift
//  CoachMeTests
//
//  Story 11.3 — Task 7.2, 7.3: Router onboarding flow and ChatViewModel discovery mode tests
//

import Testing
import Foundation
@testable import CoachMe

@MainActor
struct OnboardingFlowTests {

    // MARK: - Setup

    private func cleanUp() {
        OnboardingCoordinator.clearPersistedState()
    }

    // MARK: - Router Onboarding Flow Tests (Task 7.2)

    @Test("Router has onboarding screen case")
    func testRouterHasOnboardingScreen() {
        let router = Router()
        router.currentScreen = .onboarding
        #expect(router.currentScreen == .onboarding)
    }

    @Test("Router navigateToOnboarding sets screen to onboarding")
    func testNavigateToOnboarding() {
        let router = Router()
        router.navigateToOnboarding()
        #expect(router.currentScreen == .onboarding)
    }

    @Test("New user flows to onboarding after auth")
    func testNewUserFlowsToOnboarding() {
        cleanUp()
        let coordinator = OnboardingCoordinator()
        let router = Router()

        // Simulate auth success for new user
        if coordinator.hasCompletedOnboarding {
            router.navigateToConversationList()
        } else {
            router.navigateToOnboarding()
        }

        #expect(router.currentScreen == .onboarding)
    }

    @Test("Returning user flows to conversationList after auth")
    func testReturningUserFlowsToConversationList() {
        cleanUp()
        let coordinator = OnboardingCoordinator()
        coordinator.hasCompletedOnboarding = true
        let router = Router()

        // Simulate auth success for returning user
        if coordinator.hasCompletedOnboarding {
            router.navigateToConversationList()
        } else {
            router.navigateToOnboarding()
        }

        #expect(router.currentScreen == .conversationList)
        cleanUp()
    }

    @Test("After onboarding completes, next launch goes to conversationList")
    func testAfterOnboardingNextLaunchGoesToConversationList() {
        cleanUp()
        let coordinator = OnboardingCoordinator()

        // Complete the onboarding flow
        coordinator.beginDiscovery()
        coordinator.onDiscoveryComplete()
        coordinator.onSubscriptionConfirmed()

        // Simulate next launch
        let router = Router()
        let newCoordinator = OnboardingCoordinator()

        if newCoordinator.hasCompletedOnboarding {
            router.navigateToConversationList()
        } else {
            router.navigateToOnboarding()
        }

        #expect(router.currentScreen == .conversationList)
        cleanUp()
    }

    // MARK: - ChatViewModel Discovery Mode Tests (Task 7.3)

    @Test("ChatViewModel isDiscoveryMode defaults to false")
    func testDefaultDiscoveryMode() {
        let vm = ChatViewModel()
        #expect(vm.isDiscoveryMode == false)
        #expect(vm.discoveryComplete == false)
    }

    @Test("ChatViewModel can be set to discovery mode")
    func testSetDiscoveryMode() {
        let vm = ChatViewModel()
        vm.isDiscoveryMode = true
        #expect(vm.isDiscoveryMode == true)
    }

    @Test("ChatViewModel discovery flags reset on new conversation")
    func testDiscoveryFlagsResetOnNewConversation() {
        let vm = ChatViewModel()
        vm.isDiscoveryMode = true
        vm.discoveryComplete = true

        vm.startNewConversation()

        #expect(vm.isDiscoveryMode == false)
        #expect(vm.discoveryComplete == false)
    }

    // MARK: - StreamEvent discovery_complete integration (Task 7.3)

    @Test("StreamEvent done event with discovery_complete=true decodes correctly")
    func testDoneEventWithDiscoveryComplete() throws {
        let json = """
        {"type":"done","message_id":"550e8400-e29b-41d4-a716-446655440000","usage":{"prompt_tokens":10,"completion_tokens":20,"total_tokens":30},"discovery_complete":true}
        """
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(ChatStreamService.StreamEvent.self, from: data)

        if case .done(_, _, _, let discoveryComplete, _) = event {
            #expect(discoveryComplete == true)
        } else {
            Issue.record("Expected done event with discovery_complete")
        }
    }

    @Test("ChatRequest encodes first_message flag")
    func testChatRequestEncodesFirstMessage() throws {
        let request = ChatStreamService.ChatRequest(
            message: "",
            conversationId: UUID(),
            firstMessage: true
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["first_message"] as? Bool == true)
        #expect(json?["message"] as? String == "")
    }

    @Test("ChatRequest encodes first_message as false by default")
    func testChatRequestFirstMessageDefaultFalse() throws {
        let request = ChatStreamService.ChatRequest(
            message: "Hello",
            conversationId: UUID(),
            firstMessage: false
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["first_message"] as? Bool == false)
        #expect(json?["message"] as? String == "Hello")
    }
}
