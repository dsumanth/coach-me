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
    private static let fileName = "conversation-list-cache-v1.json"

    static func load() -> ConversationListCachePayload? {
        let url = cacheFileURL()
        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ConversationListCachePayload.self, from: data)
    }

    static func save(_ payload: ConversationListCachePayload) {
        let url = cacheFileURL()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: cacheFileURL())
    }

    private static func cacheFileURL() -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return root.appendingPathComponent(fileName)
    }
}

