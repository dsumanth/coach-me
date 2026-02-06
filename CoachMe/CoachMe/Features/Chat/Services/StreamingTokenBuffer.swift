//
//  StreamingTokenBuffer.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import Foundation

/// Buffers incoming tokens for smooth rendering
/// Per UX spec: 50-100ms buffer batches 2-3 tokens for coaching pace
@MainActor
final class StreamingTokenBuffer {
    /// Callback when buffered content should be rendered
    var onFlush: ((String) -> Void)?

    /// Buffer interval in nanoseconds (75ms default)
    private let bufferInterval: UInt64 = 75_000_000

    /// Accumulated tokens waiting to be flushed
    private var pendingTokens: String = ""

    /// Current flush task
    private var flushTask: Task<Void, Never>?

    /// Whether buffer is currently active
    private var isBuffering = false

    // MARK: - Public Methods

    /// Adds a token to the buffer
    /// - Parameter token: The token string to buffer
    func addToken(_ token: String) {
        pendingTokens += token

        if !isBuffering {
            isBuffering = true
            scheduleFlush()
        }
    }

    /// Forces immediate flush of all pending tokens
    func flush() {
        flushTask?.cancel()
        flushPendingTokens()
    }

    /// Resets the buffer state
    func reset() {
        flushTask?.cancel()
        pendingTokens = ""
        isBuffering = false
    }

    // MARK: - Private Methods

    private func scheduleFlush() {
        flushTask = Task {
            try? await Task.sleep(nanoseconds: bufferInterval)
            guard !Task.isCancelled else { return }
            flushPendingTokens()
        }
    }

    private func flushPendingTokens() {
        guard !pendingTokens.isEmpty else {
            isBuffering = false
            return
        }

        let tokensToFlush = pendingTokens
        pendingTokens = ""
        onFlush?(tokensToFlush)

        // Continue buffering if more tokens arrived during flush
        if !pendingTokens.isEmpty {
            scheduleFlush()
        } else {
            isBuffering = false
        }
    }
}
