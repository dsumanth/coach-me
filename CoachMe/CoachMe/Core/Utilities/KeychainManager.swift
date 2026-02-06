//
//  KeychainManager.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/6/26.
//

import Foundation
import Security

/// Keychain key identifiers for secure credential storage
/// Per architecture.md: Use Keychain for sensitive credentials
enum KeychainKey: String {
    case accessToken = "auth.accessToken"
    case refreshToken = "auth.refreshToken"
    case userId = "auth.userId"
}

/// Thread-safe Keychain wrapper for secure credential storage
/// Per architecture.md: Use Keychain for sensitive credentials
/// Uses kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly for security
final class KeychainManager: Sendable {
    static let shared = KeychainManager()

    /// Service identifier for Keychain - matches bundle identifier
    /// All Keychain items are scoped to this service
    private let service = Bundle.main.bundleIdentifier ?? "Nimblocity-AI-Labs.CoachMe"

    /// Keychain-specific errors with user-friendly descriptions
    enum KeychainError: LocalizedError {
        case saveError(OSStatus)
        case loadError(OSStatus)
        case deleteError(OSStatus)
        case dataConversionError
        case itemNotFound

        var errorDescription: String? {
            switch self {
            case .saveError:
                return "I couldn't save your information securely. Let's try again."
            case .loadError:
                return "I had trouble retrieving your saved information."
            case .deleteError:
                return "I couldn't remove that information. Please try again."
            case .dataConversionError:
                return "Something went wrong with your data. Let's try again."
            case .itemNotFound:
                return "I couldn't find what you're looking for."
            }
        }

        /// Technical description for logging (not shown to users)
        var technicalDescription: String {
            switch self {
            case .saveError(let status):
                return "Keychain save failed (OSStatus: \(status))"
            case .loadError(let status):
                return "Keychain load failed (OSStatus: \(status))"
            case .deleteError(let status):
                return "Keychain delete failed (OSStatus: \(status))"
            case .dataConversionError:
                return "Data conversion to UTF-8 failed"
            case .itemNotFound:
                return "Keychain item not found"
            }
        }
    }

    private init() {}

    // MARK: - Core Operations

    /// Save data to Keychain for the specified key
    /// - Parameters:
    ///   - data: The data to save
    ///   - key: The keychain key identifier
    /// - Throws: KeychainError if save fails
    func save(_ data: Data, for key: KeychainKey) throws {
        // Delete any existing item first to avoid duplicates
        try? delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveError(status)
        }
    }

    /// Load data from Keychain for the specified key
    /// - Parameter key: The keychain key identifier
    /// - Returns: The stored data, or nil if not found
    /// - Throws: KeychainError if load fails (other than not found)
    func load(for key: KeychainKey) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadError(status)
        }
    }

    /// Delete data from Keychain for the specified key
    /// - Parameter key: The keychain key identifier
    /// - Throws: KeychainError if delete fails (other than not found)
    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteError(status)
        }
    }

    /// Check if data exists for the specified key
    /// - Parameter key: The keychain key identifier
    /// - Returns: true if the key exists, false otherwise
    func exists(for key: KeychainKey) -> Bool {
        do {
            return try load(for: key) != nil
        } catch {
            return false
        }
    }

    // MARK: - Convenience Methods for Codable Types

    /// Save a Codable object to Keychain
    /// - Parameters:
    ///   - value: The Codable value to save
    ///   - key: The keychain key identifier
    /// - Throws: KeychainError or encoding error
    func save<T: Codable>(_ value: T, for key: KeychainKey) throws {
        let data = try JSONEncoder().encode(value)
        try save(data, for: key)
    }

    /// Load a Codable object from Keychain
    /// - Parameter key: The keychain key identifier
    /// - Returns: The decoded object, or nil if not found
    /// - Throws: KeychainError or decoding error
    func load<T: Codable>(for key: KeychainKey) throws -> T? {
        guard let data = try load(for: key) else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - String Convenience Methods

    /// Save a string value to Keychain
    /// - Parameters:
    ///   - string: The string to save
    ///   - key: The keychain key identifier
    /// - Throws: KeychainError if save fails
    func save(_ string: String, for key: KeychainKey) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        try save(data, for: key)
    }

    /// Load a string value from Keychain
    /// - Parameter key: The keychain key identifier
    /// - Returns: The stored string, or nil if not found
    /// - Throws: KeychainError if load fails
    func loadString(for key: KeychainKey) throws -> String? {
        guard let data = try load(for: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Bulk Operations

    /// Clear all authentication-related Keychain entries
    /// Used during sign out to ensure all credentials are removed
    func clearAllAuthData() throws {
        try delete(for: .accessToken)
        try delete(for: .refreshToken)
        try delete(for: .userId)
    }
}
