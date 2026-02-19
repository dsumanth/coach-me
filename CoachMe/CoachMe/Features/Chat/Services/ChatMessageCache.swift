//
//  ChatMessageCache.swift
//  CoachMe
//
//  Lightweight per-conversation message cache for instant thread loading.
//

import Foundation

enum ChatMessageCache {
    private static let cacheDirectoryName = "chat-message-cache-v1"

    static func load(conversationId: UUID) -> [ChatMessage]? {
        migrateLegacyCacheIfNeeded()
        let url = fileURL(for: conversationId)
        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([ChatMessage].self, from: data)
    }

    static func save(messages: [ChatMessage], conversationId: UUID) {
        migrateLegacyCacheIfNeeded()
        let url = fileURL(for: conversationId)
        ensureCacheDirectoryExists()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(messages) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func remove(conversationId: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: conversationId))
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectoryURL())
        try? FileManager.default.removeItem(at: legacyCacheDirectoryURL())
    }

    private static func fileURL(for conversationId: UUID) -> URL {
        cacheDirectoryURL().appendingPathComponent("\(conversationId.uuidString).json")
    }

    private static func cacheDirectoryURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return root.appendingPathComponent(cacheDirectoryName, isDirectory: true)
    }

    private static func legacyCacheDirectoryURL() -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return root.appendingPathComponent(cacheDirectoryName, isDirectory: true)
    }

    private static func ensureCacheDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: cacheDirectoryURL(),
            withIntermediateDirectories: true
        )
    }

    /// One-time migration from cache directory to app support directory
    /// so chat history survives routine cache eviction.
    private static func migrateLegacyCacheIfNeeded() {
        let fileManager = FileManager.default
        let newURL = cacheDirectoryURL()
        let oldURL = legacyCacheDirectoryURL()

        guard fileManager.fileExists(atPath: oldURL.path) else { return }
        ensureCacheDirectoryExists()

        guard let oldFiles = try? fileManager.contentsOfDirectory(at: oldURL, includingPropertiesForKeys: nil) else {
            return
        }

        for oldFile in oldFiles where oldFile.pathExtension == "json" {
            let newFile = newURL.appendingPathComponent(oldFile.lastPathComponent)
            if fileManager.fileExists(atPath: newFile.path) { continue }
            try? fileManager.copyItem(at: oldFile, to: newFile)
        }
    }
}
