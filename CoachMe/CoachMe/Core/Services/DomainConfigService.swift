//
//  DomainConfigService.swift
//  CoachMe
//
//  Story 3.2: Domain Configuration Engine
//  Loads and caches domain configs from the app bundle.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Protocol for domain config access, enabling mock-based testing.
@MainActor
protocol DomainConfigServiceProtocol {
    /// Get the config for a specific domain. Returns general fallback if not found.
    func config(for domain: CoachingDomain) -> DomainConfig

    /// All loaded domain configs.
    var allConfigs: [CoachingDomain: DomainConfig] { get }
}

// MARK: - Service

/// Loads all domain JSON configs from the app bundle at init and caches them in memory.
/// Follows @MainActor singleton pattern like ConversationService.shared.
@MainActor
final class DomainConfigService: DomainConfigServiceProtocol {

    static let shared = DomainConfigService()

    private(set) var allConfigs: [CoachingDomain: DomainConfig] = [:]

    private let logger = Logger(subsystem: "com.coachme.app", category: "DomainConfigService")

    private init() {
        loadConfigs()
    }

    /// Designated initializer for testing — accepts a custom bundle.
    init(bundle: Bundle) {
        loadConfigs(from: bundle)
    }

    // MARK: - Public API

    func config(for domain: CoachingDomain) -> DomainConfig {
        if let cfg = allConfigs[domain], cfg.enabled {
            return cfg
        }
        // Fallback to general config from cache, or hardcoded factory
        return allConfigs[.general] ?? DomainConfig.general()
    }

    // MARK: - Loading

    private func loadConfigs(from bundle: Bundle = .main) {
        guard let configURLs = bundle.urls(
            forResourcesWithExtension: "json",
            subdirectory: "DomainConfigs"
        ) else {
            logger.warning("No DomainConfigs directory found in bundle")
            allConfigs[.general] = DomainConfig.general()
            return
        }

        let decoder = JSONDecoder()

        for url in configURLs {
            do {
                let data = try Data(contentsOf: url)
                let config = try decoder.decode(DomainConfig.self, from: data)

                guard let domain = CoachingDomain(rawValue: config.id) else {
                    logger.warning("Unknown domain id '\(config.id)' in \(url.lastPathComponent), skipping")
                    continue
                }

                allConfigs[domain] = config
            } catch {
                logger.warning("I couldn't load domain config from \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Ensure general fallback always exists
        if allConfigs[.general] == nil {
            logger.info("No general.json found, using built-in fallback")
            allConfigs[.general] = DomainConfig.general()
        }

        logger.info("Loaded \(self.allConfigs.count) domain configs")
    }
}
