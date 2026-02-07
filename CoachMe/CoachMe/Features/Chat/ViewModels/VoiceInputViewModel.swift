//
//  VoiceInputViewModel.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import Foundation
import SwiftUI

/// ViewModel for voice input functionality
/// Per architecture.md: Use @Observable for ViewModels (not @ObservableObject)
@MainActor
@Observable
final class VoiceInputViewModel {
    // MARK: - Published State

    /// Whether currently recording
    var isRecording = false

    /// Whether processing speech
    var isProcessing = false

    /// Transcribed text (partial during recording, final after)
    var transcribedText: String = ""

    /// Current error
    var error: VoiceInputError?

    /// Whether to show error alert
    var showError = false

    /// Whether to show permission sheet
    var showPermissionSheet = false

    /// Permission status
    var permissionStatus: PermissionStatus = .notDetermined

    /// Tracks whether any speech was detected during current recording session
    /// Fix for code review M1: Moved from VoiceInputService to avoid Swift 6 concurrency issues
    private var hasSpeechBeenDetected = false

    /// Tracks when recording started to enforce minimum duration
    /// Users must hold for at least this duration for a valid recording
    private var recordingStartTime: Date?

    /// Minimum recording duration in seconds before showing "no speech detected" error
    /// Quick taps shorter than this are silently ignored (not real recording attempts)
    private static let minimumRecordingDuration: TimeInterval = 0.5

    enum PermissionStatus {
        case notDetermined
        case authorized
        case denied
    }

    // MARK: - Dependencies

    private let voiceInputService: VoiceInputService
    private let networkMonitor: NetworkMonitor

    // MARK: - Initialization

    init(
        voiceInputService: VoiceInputService = VoiceInputService(),
        networkMonitor: NetworkMonitor = .shared
    ) {
        self.voiceInputService = voiceInputService
        self.networkMonitor = networkMonitor
    }

    // MARK: - Actions

    /// Starts voice recording
    func startRecording() async {
        // Check network (speech recognition requires internet)
        guard networkMonitor.isConnected else {
            error = .networkUnavailable
            showError = true
            return
        }

        // Check permissions
        let speechAuth = voiceInputService.checkSpeechAuthorization()
        let micAuth = voiceInputService.checkMicrophoneAuthorization()

        if speechAuth == .notDetermined || micAuth == .notDetermined {
            showPermissionSheet = true
            return
        }

        // Handle denied or restricted states
        if speechAuth == .denied || speechAuth == .restricted {
            error = .permissionDenied
            showError = true
            return
        }

        if micAuth == .denied || micAuth == .restricted {
            error = .microphonePermissionDenied
            showError = true
            return
        }

        // Start recording
        do {
            isRecording = true
            transcribedText = ""
            hasSpeechBeenDetected = false  // Reset for new recording session
            recordingStartTime = Date()  // Track start time for minimum duration check

            try await voiceInputService.startRecording(
                onPartialResult: { [weak self] text in
                    Task { @MainActor in
                        self?.transcribedText = text
                        // Track that speech was detected (fix for code review M1)
                        if !text.isEmpty {
                            self?.hasSpeechBeenDetected = true
                        }
                    }
                },
                onFinalResult: { [weak self] text in
                    Task { @MainActor in
                        self?.transcribedText = text
                        self?.isRecording = false
                        // Track that speech was detected (fix for code review M1)
                        if !text.isEmpty {
                            self?.hasSpeechBeenDetected = true
                        }
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.error = error
                        self?.showError = true
                        self?.isRecording = false
                    }
                }
            )
        } catch let error as VoiceInputError {
            self.error = error
            showError = true
            isRecording = false
        } catch {
            self.error = .recognitionFailed(error)
            showError = true
            isRecording = false
        }
    }

    /// Stops voice recording
    func stopRecording() async {
        // Check if we were recording and no speech was detected
        let wasRecording = isRecording
        let noSpeechDetected = !hasSpeechBeenDetected

        // Calculate recording duration to distinguish real recordings from quick taps
        let recordingDuration: TimeInterval
        if let startTime = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        } else {
            recordingDuration = 0
        }

        await voiceInputService.stopRecording()
        isRecording = false
        recordingStartTime = nil

        // Only show "no speech detected" error if:
        // 1. We were actually recording
        // 2. No speech was detected
        // 3. Recording duration exceeded minimum threshold (not just a quick tap)
        if wasRecording && noSpeechDetected && recordingDuration >= Self.minimumRecordingDuration {
            error = .noSpeechDetected
            showError = true
        }
    }

    /// Requests permissions
    func requestPermissions() async {
        let speechGranted = await voiceInputService.requestSpeechAuthorization()
        let micGranted = await voiceInputService.requestMicrophoneAuthorization()

        // Always dismiss the permission sheet after requesting
        showPermissionSheet = false

        if speechGranted && micGranted {
            permissionStatus = .authorized
            await startRecording()
        } else {
            permissionStatus = .denied
            if !speechGranted {
                error = .permissionDenied
            } else {
                error = .microphonePermissionDenied
            }
            showError = true
        }
    }

    /// Clears transcribed text
    func clearTranscript() {
        transcribedText = ""
    }

    /// Dismisses error
    func dismissError() {
        showError = false
        error = nil
    }

    /// Dismisses permission sheet
    func dismissPermissionSheet() {
        showPermissionSheet = false
    }
}
