//
//  VoiceInputService.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import Foundation
import Speech
import AVFoundation

/// Service for handling voice input and speech recognition
/// Per architecture.md: Use actor-based services for thread-safe shared state
actor VoiceInputService {
    // MARK: - Types

    enum AuthorizationStatus: Sendable {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    enum RecognitionState: Sendable {
        case idle
        case recording
        case processing
    }

    // MARK: - Constants

    /// Maximum recording duration in seconds (fix for code review M2)
    static let maxRecordingDuration: TimeInterval = 60.0

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?

    /// Error callback for timeout scenarios
    private var storedOnError: (@Sendable (VoiceInputError) -> Void)?

    private(set) var state: RecognitionState = .idle

    // MARK: - Initialization

    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Authorization

    nonisolated func checkSpeechAuthorization() -> AuthorizationStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    nonisolated func checkMicrophoneAuthorization() -> AuthorizationStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: return .notDetermined
        case .granted: return .authorized
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func requestMicrophoneAuthorization() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording

    func startRecording(
        onPartialResult: @escaping @Sendable (String) -> Void,
        onFinalResult: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (VoiceInputError) -> Void
    ) throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceInputError.notAvailable
        }

        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil

        // Store error callback for timeout (fix for code review M2)
        storedOnError = onError

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw VoiceInputError.audioSessionFailed
        }

        // Create new audio engine
        let newAudioEngine = AVAudioEngine()
        self.audioEngine = newAudioEngine

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = request
        request.shouldReportPartialResults = true

        // Configure audio input
        let inputNode = newAudioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Capture request directly to avoid actor-isolation issues
        // SFSpeechAudioBufferRecognitionRequest.append is thread-safe
        let capturedRequest = request
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            capturedRequest.append(buffer)
        }

        // Start audio engine
        newAudioEngine.prepare()
        do {
            try newAudioEngine.start()
        } catch {
            throw VoiceInputError.audioSessionFailed
        }

        state = .recording

        // Start recording timeout (fix for code review M2)
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.maxRecordingDuration))
            guard !Task.isCancelled else { return }
            await self?.handleTimeout()
        }

        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                onError(VoiceInputError.recognitionFailed(error))
                return
            }

            guard let result = result else { return }

            let transcription = result.bestTranscription.formattedString

            if result.isFinal {
                onFinalResult(transcription)
            } else {
                onPartialResult(transcription)
            }
        }
    }

    /// Handles recording timeout (fix for code review M2)
    private func handleTimeout() {
        guard state == .recording else { return }
        stopRecording()
        // Timeout with no final result means no speech detected
        storedOnError?(.noSpeechDetected)
    }

    func stopRecording() {
        // Cancel timeout task (fix for code review M2)
        timeoutTask?.cancel()
        timeoutTask = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        // Signal end of audio input - the recognition task will finish naturally
        // and deliver a final result. Do NOT call recognitionTask?.cancel() here
        // as that triggers an error callback instead of a final result.
        recognitionRequest?.endAudio()

        // Clean up references but let the recognition task complete naturally
        recognitionRequest = nil
        audioEngine = nil
        state = .idle
        storedOnError = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func cancelRecording() {
        stopRecording()
    }
}
