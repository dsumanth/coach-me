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

        if speechAuth == .denied {
            error = .permissionDenied
            showError = true
            return
        }

        if micAuth == .denied {
            error = .microphonePermissionDenied
            showError = true
            return
        }

        // Start recording
        do {
            isRecording = true
            transcribedText = ""
            hasSpeechBeenDetected = false  // Reset for new recording session

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

        await voiceInputService.stopRecording()
        isRecording = false

        // Show error if no speech was detected during recording (fix for code review M1)
        if wasRecording && noSpeechDetected {
            error = .noSpeechDetected
            showError = true
        }
    }

    /// Requests permissions
    func requestPermissions() async {
        let speechGranted = await voiceInputService.requestSpeechAuthorization()
        let micGranted = await voiceInputService.requestMicrophoneAuthorization()

        if speechGranted && micGranted {
            permissionStatus = .authorized
            showPermissionSheet = false
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
