//
//  ConversationListCache.swift
//  CoachMe
//
//  Lightweight on-device cache for inbox conversations and previews.
//

import Foundation

struct ConversationListCachePayload: Codable {
    let conversations: [ConversationService.Conversation]
    let previews: [UUID: String]
    let roles: [UUID: ChatMessage.Role]
    let cachedAt: Date
}

enum ConversationListCache {
    private static let cacheDirectoryName = "conversation-list-cache-v1"
    private static let fileName = "conversation-list-cache-v1.json"

    static func load() -> ConversationListCachePayload? {
        migrateLegacyCacheIfNeeded()
        let url = cacheFileURL()
        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ConversationListCachePayload.self, from: data)
    }

    static func save(_ payload: ConversationListCachePayload) {
        migrateLegacyCacheIfNeeded()
        let url = cacheFileURL()
        ensureCacheDirectoryExists()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: cacheFileURL())
        try? FileManager.default.removeItem(at: legacyCacheFileURL())
    }

    private static func cacheFileURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return root
            .appendingPathComponent(cacheDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static func legacyCacheFileURL() -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return root.appendingPathComponent(fileName)
    }

    private static func ensureCacheDirectoryExists() {
        let directory = cacheFileURL().deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    private static func migrateLegacyCacheIfNeeded() {
        let fileManager = FileManager.default
        let newURL = cacheFileURL()
        let oldURL = legacyCacheFileURL()

        guard fileManager.fileExists(atPath: oldURL.path) else { return }
        ensureCacheDirectoryExists()
        guard !fileManager.fileExists(atPath: newURL.path) else { return }

        try? fileManager.copyItem(at: oldURL, to: newURL)
    }
}
