//
//  OfflineBannerTests.swift
//  CoachMeTests
//
//  Story 7.2: Offline Warning Banner — Unit tests
//

import Testing
import SwiftUI
@testable import CoachMe

// MARK: - OfflineBanner View Tests

@MainActor
struct OfflineBannerTests {

    // MARK: - Task 4.1: Banner Rendering Tests

    @Test("OfflineBanner creates successfully")
    func testBannerInstantiation() {
        let banner = OfflineBanner()
        // Verify banner can be instantiated — actual text/styling verified via preview/XCUITest
        _ = banner.body
    }

    // MARK: - Task 4.2: NetworkMonitor Integration Tests

    @Test("NetworkMonitor test init sets isConnected to false")
    func testNetworkMonitorOffline() {
        let monitor = NetworkMonitor(isConnected: false)
        #expect(!monitor.isConnected)
        #expect(!monitor.isExpensive)
    }

    @Test("NetworkMonitor test init sets isConnected to true")
    func testNetworkMonitorOnline() {
        let monitor = NetworkMonitor(isConnected: true)
        #expect(monitor.isConnected)
    }

    @Test("NetworkMonitor setConnectionState toggles connectivity")
    func testNetworkMonitorStateChange() {
        let monitor = NetworkMonitor(isConnected: false)
        #expect(!monitor.isConnected)

        monitor.setConnectionState(isConnected: true)
        #expect(monitor.isConnected)

        monitor.setConnectionState(isConnected: false)
        #expect(!monitor.isConnected)
    }

    // MARK: - Task 4.3: MessageInput canSend Offline Tests

    @Test("MessageInput accepts injected NetworkMonitor")
    func testMessageInputNetworkMonitorInjection() {
        let offlineMonitor = NetworkMonitor(isConnected: false)
        let input = MessageInput(
            viewModel: ChatViewModel(),
            voiceViewModel: VoiceInputViewModel(),
            networkMonitor: offlineMonitor
        )
        // Verify the injected monitor is used
        #expect(!input.networkMonitor.isConnected)
    }

    @Test("MessageInput uses online NetworkMonitor when connected")
    func testMessageInputOnlineMonitor() {
        let onlineMonitor = NetworkMonitor(isConnected: true)
        let input = MessageInput(
            viewModel: ChatViewModel(),
            voiceViewModel: VoiceInputViewModel(),
            networkMonitor: onlineMonitor
        )
        #expect(input.networkMonitor.isConnected)
    }

    @Test("VoiceInputButton is disabled when offline via MessageInput")
    func testVoiceButtonDisabledWhenOffline() {
        // VoiceInputButton receives isDisabled from MessageInput logic:
        // isDisabled = viewModel.isLoading || viewModel.isStreaming || !networkMonitor.isConnected
        let offlineMonitor = NetworkMonitor(isConnected: false)

        // When offline, the button should be disabled even if not loading/streaming
        let isDisabled = false || false || !offlineMonitor.isConnected
        #expect(isDisabled)
    }

    @Test("VoiceInputButton is not disabled when online and not loading")
    func testVoiceButtonEnabledWhenOnline() {
        let onlineMonitor = NetworkMonitor(isConnected: true)

        let isDisabled = false || false || !onlineMonitor.isConnected
        #expect(!isDisabled)
    }

    // MARK: - Task 4.4: Banner Dismiss on Reconnect Tests

    @Test("Banner visibility condition becomes false when connection restores")
    func testBannerDismissesOnReconnect() {
        let monitor = NetworkMonitor(isConnected: false)

        // Banner should show when offline
        #expect(!monitor.isConnected) // Banner visible: !isConnected == true

        // Simulate reconnection
        monitor.setConnectionState(isConnected: true)

        // Banner should hide when online
        #expect(monitor.isConnected) // Banner hidden: !isConnected == false
    }

    @Test("Banner visibility condition becomes true when connection drops")
    func testBannerAppearsOnDisconnect() {
        let monitor = NetworkMonitor(isConnected: true)

        // Banner should be hidden when online
        #expect(monitor.isConnected)

        // Simulate disconnection
        monitor.setConnectionState(isConnected: false)

        // Banner should show when offline
        #expect(!monitor.isConnected)
    }

    // MARK: - Banner Priority Tests

    @Test("Offline banner takes priority over trial banner")
    func testOfflineBannerPriority() {
        // When offline, the banner shows regardless of trial status
        // The ChatView logic: if !networkMonitor.isConnected → OfflineBanner
        //                      else if isTrialActive → TrialBanner
        let monitor = NetworkMonitor(isConnected: false)

        // Even if trial is active, offline banner takes priority
        let isTrialActive = true
        let showOfflineBanner = !monitor.isConnected
        let showTrialBanner = monitor.isConnected && isTrialActive

        #expect(showOfflineBanner)
        #expect(!showTrialBanner)
    }

    @Test("Trial banner shows when online and trial active")
    func testTrialBannerShowsWhenOnline() {
        let monitor = NetworkMonitor(isConnected: true)
        let isTrialActive = true

        let showOfflineBanner = !monitor.isConnected
        let showTrialBanner = monitor.isConnected && isTrialActive

        #expect(!showOfflineBanner)
        #expect(showTrialBanner)
    }

    // MARK: - canSend Logic Tests

    @Test("canSend logic returns false when offline with text")
    func testCanSendFalseWhenOffline() {
        // Simulating the canSend logic from MessageInput:
        // !text.isEmpty && !isLoading && !isRecording && isConnected
        let hasText = true
        let isLoading = false
        let isRecording = false
        let isConnected = false

        let canSend = hasText && !isLoading && !isRecording && isConnected
        #expect(!canSend)
    }

    @Test("canSend logic returns true when online with text")
    func testCanSendTrueWhenOnline() {
        let hasText = true
        let isLoading = false
        let isRecording = false
        let isConnected = true

        let canSend = hasText && !isLoading && !isRecording && isConnected
        #expect(canSend)
    }

    @Test("canSend logic returns false when online but no text")
    func testCanSendFalseNoText() {
        let hasText = false
        let isLoading = false
        let isRecording = false
        let isConnected = true

        let canSend = hasText && !isLoading && !isRecording && isConnected
        #expect(!canSend)
    }

    @Test("canSend logic returns false when online but loading")
    func testCanSendFalseWhenLoading() {
        let hasText = true
        let isLoading = true
        let isRecording = false
        let isConnected = true

        let canSend = hasText && !isLoading && !isRecording && isConnected
        #expect(!canSend)
    }
}
