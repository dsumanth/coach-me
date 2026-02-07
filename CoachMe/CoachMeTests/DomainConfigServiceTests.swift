//
//  DomainConfigServiceTests.swift
//  CoachMeTests
//
//  Story 3.2: Domain Configuration Engine
//  Tests for DomainConfigService, DomainConfig model, and CoachingDomain enum.
//

import Testing
import Foundation
@testable import CoachMe

// MARK: - DomainConfig Model Decoding Tests

struct DomainConfigDecodingTests {

    @Test("Decode career config from JSON with all fields")
    func testDecodeFullConfig() throws {
        let json = """
        {
          "id": "career",
          "name": "Career Coaching",
          "description": "Professional growth",
          "systemPromptAddition": "You are a career coach.",
          "tone": "professional, encouraging",
          "methodology": "SMART framework",
          "personality": "experienced career mentor",
          "domainKeywords": ["career", "job", "work"],
          "focusAreas": ["career growth", "networking"],
          "enabled": true
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(DomainConfig.self, from: json)
        #expect(config.id == "career")
        #expect(config.name == "Career Coaching")
        #expect(config.description == "Professional growth")
        #expect(config.systemPromptAddition == "You are a career coach.")
        #expect(config.tone == "professional, encouraging")
        #expect(config.methodology == "SMART framework")
        #expect(config.personality == "experienced career mentor")
        #expect(config.domainKeywords == ["career", "job", "work"])
        #expect(config.focusAreas == ["career growth", "networking"])
        #expect(config.enabled == true)
    }

    @Test("Decode general config with empty arrays and empty string")
    func testDecodeGeneralConfig() throws {
        let json = """
        {
          "id": "general",
          "name": "General Coaching",
          "description": "Broad coaching",
          "systemPromptAddition": "",
          "tone": "warm, supportive",
          "methodology": "active listening",
          "personality": "empathetic coach",
          "domainKeywords": [],
          "focusAreas": [],
          "enabled": true
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(DomainConfig.self, from: json)
        #expect(config.id == "general")
        #expect(config.systemPromptAddition.isEmpty)
        #expect(config.domainKeywords.isEmpty)
        #expect(config.focusAreas.isEmpty)
    }

    @Test("DomainConfig conforms to Sendable")
    func testSendable() throws {
        let config = DomainConfig.general()
        // If this compiles, Sendable conformance is satisfied
        let _: any Sendable = config
        #expect(config.id == "general")
    }
}

// MARK: - DomainConfig Factory Tests

struct DomainConfigFactoryTests {

    @Test("general() returns correct fallback config")
    func testGeneralFactory() {
        let config = DomainConfig.general()
        #expect(config.id == "general")
        #expect(config.name == "General Coaching")
        #expect(config.systemPromptAddition.isEmpty)
        #expect(config.tone == "warm, supportive, curious")
        #expect(config.domainKeywords.isEmpty)
        #expect(config.focusAreas.isEmpty)
        #expect(config.enabled == true)
    }
}

// MARK: - CoachingDomain Enum Tests

struct CoachingDomainTests {

    @Test("All enum cases have matching raw values for JSON id fields")
    func testRawValues() {
        #expect(CoachingDomain.life.rawValue == "life")
        #expect(CoachingDomain.career.rawValue == "career")
        #expect(CoachingDomain.relationships.rawValue == "relationships")
        #expect(CoachingDomain.mindset.rawValue == "mindset")
        #expect(CoachingDomain.creativity.rawValue == "creativity")
        #expect(CoachingDomain.fitness.rawValue == "fitness")
        #expect(CoachingDomain.leadership.rawValue == "leadership")
        #expect(CoachingDomain.general.rawValue == "general")
    }

    @Test("CoachingDomain has exactly 8 cases")
    func testCaseCount() {
        #expect(CoachingDomain.allCases.count == 8)
    }
}

// MARK: - DomainConfigService Tests

@MainActor
struct DomainConfigServiceTests {

    @Test("Service loads all 8 configs from bundle")
    func testLoadAllConfigs() {
        let service = DomainConfigService.shared
        // Should have all 8 configs (7 domains + general)
        #expect(service.allConfigs.count == 8)
        for domain in CoachingDomain.allCases {
            #expect(service.allConfigs[domain] != nil, "Missing config for \(domain.rawValue)")
        }
    }

    @Test("config(for:) returns correct config for known domain")
    func testConfigForKnownDomain() {
        let service = DomainConfigService.shared
        let careerConfig = service.config(for: .career)
        #expect(careerConfig.id == "career")
        #expect(careerConfig.name == "Career Coaching")
        #expect(!careerConfig.systemPromptAddition.isEmpty)
        #expect(!careerConfig.domainKeywords.isEmpty)
    }

    @Test("config(for: .general) returns general config")
    func testConfigForGeneral() {
        let service = DomainConfigService.shared
        let config = service.config(for: .general)
        #expect(config.id == "general")
        #expect(config.systemPromptAddition.isEmpty)
        #expect(config.domainKeywords.isEmpty)
    }

    @Test("Each domain config has required non-empty fields")
    func testAllConfigsHaveRequiredFields() {
        let service = DomainConfigService.shared
        for domain in CoachingDomain.allCases {
            let config = service.config(for: domain)
            #expect(!config.id.isEmpty, "\(domain.rawValue): id is empty")
            #expect(!config.name.isEmpty, "\(domain.rawValue): name is empty")
            #expect(!config.description.isEmpty, "\(domain.rawValue): description is empty")
            #expect(!config.tone.isEmpty, "\(domain.rawValue): tone is empty")
            #expect(!config.methodology.isEmpty, "\(domain.rawValue): methodology is empty")
            #expect(!config.personality.isEmpty, "\(domain.rawValue): personality is empty")
            #expect(config.enabled == true, "\(domain.rawValue): should be enabled")
        }
    }

    @Test("Non-general domains have keywords and systemPromptAddition")
    func testNonGeneralDomainsHaveContent() {
        let service = DomainConfigService.shared
        for domain in CoachingDomain.allCases where domain != .general {
            let config = service.config(for: domain)
            #expect(!config.systemPromptAddition.isEmpty, "\(domain.rawValue): systemPromptAddition is empty")
            #expect(!config.domainKeywords.isEmpty, "\(domain.rawValue): domainKeywords is empty")
            #expect(!config.focusAreas.isEmpty, "\(domain.rawValue): focusAreas is empty")
        }
    }

    @Test("Config id matches CoachingDomain rawValue")
    func testConfigIdMatchesDomain() {
        let service = DomainConfigService.shared
        for domain in CoachingDomain.allCases {
            let config = service.config(for: domain)
            #expect(config.id == domain.rawValue, "\(domain.rawValue): config.id '\(config.id)' doesn't match rawValue")
        }
    }
}

// MARK: - Mock DomainConfigService

@MainActor
struct MockDomainConfigServiceTests {

    @Test("Protocol enables mock-based testing")
    func testProtocolMocking() {
        let mock = MockDomainConfigService()
        let config = mock.config(for: .career)
        #expect(config.id == "mock-career")
    }
}

/// Mock for DomainConfigServiceProtocol testing
@MainActor
private final class MockDomainConfigService: DomainConfigServiceProtocol {
    var allConfigs: [CoachingDomain: DomainConfig] = [:]

    func config(for domain: CoachingDomain) -> DomainConfig {
        DomainConfig(
            id: "mock-\(domain.rawValue)",
            name: "Mock \(domain.rawValue)",
            description: "Mock config",
            systemPromptAddition: "Mock prompt",
            tone: "mock",
            methodology: "mock",
            personality: "mock",
            domainKeywords: [],
            focusAreas: [],
            enabled: true
        )
    }
}
