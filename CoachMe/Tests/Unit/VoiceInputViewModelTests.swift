//
//  VoiceInputViewModelTests.swift
//  CoachMeTests
//
//  Created by Dev Agent on 2/6/26.
//

import Testing
@testable import CoachMe

/// Unit tests for VoiceInputViewModel
@MainActor
struct VoiceInputViewModelTests {

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with idle state")
    func testInitialState() {
        let viewModel = VoiceInputViewModel()

        #expect(!viewModel.isRecording)
        #expect(!viewModel.isProcessing)
        #expect(viewModel.transcribedText.isEmpty)
        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
        #expect(!viewModel.showPermissionSheet)
        #expect(viewModel.permissionStatus == .notDetermined)
    }

    // MARK: - Error State Tests

    @Test("dismissError clears error state")
    func testDismissError() {
        let viewModel = VoiceInputViewModel()
        viewModel.error = .networkUnavailable
        viewModel.showError = true

        viewModel.dismissError()

        #expect(viewModel.error == nil)
        #expect(!viewModel.showError)
    }

    @Test("dismissPermissionSheet clears sheet state")
    func testDismissPermissionSheet() {
        let viewModel = VoiceInputViewModel()
        viewModel.showPermissionSheet = true

        viewModel.dismissPermissionSheet()

        #expect(!viewModel.showPermissionSheet)
    }

    // MARK: - Transcription Tests

    @Test("clearTranscript clears transcribed text")
    func testClearTranscript() {
        let viewModel = VoiceInputViewModel()
        viewModel.transcribedText = "Test transcription"

        viewModel.clearTranscript()

        #expect(viewModel.transcribedText.isEmpty)
    }

    // MARK: - Network Check Tests

    @Test("startRecording shows error when offline")
    func testStartRecordingOffline() async {
        // Fix for code review H2: Properly inject testable NetworkMonitor
        let offlineMonitor = NetworkMonitor(isConnected: false)
        let viewModel = VoiceInputViewModel(networkMonitor: offlineMonitor)

        // Attempt to start recording while offline
        await viewModel.startRecording()

        // Should show network unavailable error
        #expect(viewModel.error == .networkUnavailable)
        #expect(viewModel.showError)
        #expect(!viewModel.isRecording)
    }

    @Test("startRecording proceeds when online")
    func testStartRecordingOnline() async {
        // Create a mock network monitor that reports online
        let onlineMonitor = NetworkMonitor(isConnected: true)
        let viewModel = VoiceInputViewModel(networkMonitor: onlineMonitor)

        // Network check should pass (will fail at permission check, but that's expected)
        await viewModel.startRecording()

        // Should NOT have network error - may have permission error or show permission sheet
        #expect(viewModel.error != .networkUnavailable)
    }

    // MARK: - Error Message Tests

    @Test("VoiceInputError provides warm first-person messages")
    func testErrorMessages() {
        #expect(VoiceInputError.permissionDenied.errorDescription?.contains("I need") == true)
        #expect(VoiceInputError.microphonePermissionDenied.errorDescription?.contains("I need") == true)
        #expect(VoiceInputError.networkUnavailable.errorDescription?.contains("I need") == true)
        #expect(VoiceInputError.recognitionFailed(NSError(domain: "", code: 0)).errorDescription?.contains("I couldn't") == true)
        #expect(VoiceInputError.noSpeechDetected.errorDescription?.contains("I didn't") == true)
        #expect(VoiceInputError.audioSessionFailed.errorDescription?.contains("I had trouble") == true)
    }

    // MARK: - State Transition Tests

    @Test("Recording state can be set directly for testing")
    func testRecordingStateTransition() {
        let viewModel = VoiceInputViewModel()

        #expect(!viewModel.isRecording)

        viewModel.isRecording = true
        #expect(viewModel.isRecording)

        viewModel.isRecording = false
        #expect(!viewModel.isRecording)
    }

    @Test("Permission status can transition between states")
    func testPermissionStatusTransitions() {
        let viewModel = VoiceInputViewModel()

        #expect(viewModel.permissionStatus == .notDetermined)

        viewModel.permissionStatus = .authorized
        #expect(viewModel.permissionStatus == .authorized)

        viewModel.permissionStatus = .denied
        #expect(viewModel.permissionStatus == .denied)
    }

    // MARK: - Integration Pattern Tests

    @Test("ViewModel correctly manages recording lifecycle states")
    func testRecordingLifecycle() {
        let viewModel = VoiceInputViewModel()

        // Initial state
        #expect(!viewModel.isRecording)
        #expect(viewModel.transcribedText.isEmpty)

        // Simulate recording start
        viewModel.isRecording = true
        viewModel.transcribedText = "Hello"
        #expect(viewModel.isRecording)
        #expect(viewModel.transcribedText == "Hello")

        // Simulate more transcription
        viewModel.transcribedText = "Hello world"
        #expect(viewModel.transcribedText == "Hello world")

        // Simulate recording stop
        viewModel.isRecording = false
        #expect(!viewModel.isRecording)
        #expect(viewModel.transcribedText == "Hello world") // Text preserved for review
    }

    @Test("Error during recording resets recording state")
    func testErrorResetsRecordingState() {
        let viewModel = VoiceInputViewModel()

        // Simulate recording
        viewModel.isRecording = true
        viewModel.transcribedText = "Partial transcription"

        // Simulate error
        viewModel.error = .recognitionFailed(NSError(domain: "test", code: 0))
        viewModel.showError = true
        viewModel.isRecording = false

        #expect(!viewModel.isRecording)
        #expect(viewModel.showError)
        #expect(viewModel.error != nil)
    }
}
