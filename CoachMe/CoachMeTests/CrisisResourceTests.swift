//
//  CrisisResourceTests.swift
//  CoachMeTests
//
//  Story 4.2: Crisis Resource Display
//  Tests for CrisisResource data model and crisis-specific design system colors
//

import Testing
import SwiftUI
@testable import CoachMe

// MARK: - Crisis Resource Model Tests

@Suite("CrisisResource Model Tests")
@MainActor
struct CrisisResourceModelTests {

    @Test("CrisisResource has required properties")
    func crisisResourceProperties() {
        let resource = CrisisResource(
            name: "Test Resource",
            description: "Test description",
            phoneNumber: "123",
            textNumber: nil,
            textBody: nil,
            availability: "24/7"
        )

        #expect(resource.name == "Test Resource")
        #expect(resource.description == "Test description")
        #expect(resource.phoneNumber == "123")
        #expect(resource.textNumber == nil)
        #expect(resource.textBody == nil)
        #expect(resource.availability == "24/7")
    }

    @Test("CrisisResource is Identifiable")
    func crisisResourceIdentifiable() {
        let resource1 = CrisisResource(
            name: "Resource 1",
            description: "Description 1",
            phoneNumber: "111",
            textNumber: nil,
            textBody: nil,
            availability: "24/7"
        )
        let resource2 = CrisisResource(
            name: "Resource 2",
            description: "Description 2",
            phoneNumber: "222",
            textNumber: nil,
            textBody: nil,
            availability: "24/7"
        )

        #expect(resource1.id != resource2.id)
    }
}

// MARK: - Crisis Resource Constants Tests

@Suite("CrisisResource Constants Tests")
@MainActor
struct CrisisResourceConstantsTests {

    @Test("988 Suicide & Crisis Lifeline has correct properties")
    func suicideCrisisLifeline() {
        let lifeline = CrisisResource.suicideCrisisLifeline

        #expect(lifeline.name.contains("988"))
        #expect(lifeline.phoneNumber == "988")
        #expect(lifeline.availability == "24/7")
    }

    @Test("Crisis Text Line has correct properties")
    func crisisTextLine() {
        let textLine = CrisisResource.crisisTextLine

        #expect(textLine.name.contains("Crisis Text Line"))
        #expect(textLine.textNumber == "741741")
        #expect(textLine.textBody == "HELLO")
        #expect(textLine.availability == "24/7")
    }

    @Test("Emergency 911 has correct properties")
    func emergency911() {
        let emergency = CrisisResource.emergency911

        #expect(emergency.name.contains("911"))
        #expect(emergency.phoneNumber == "911")
    }

    @Test("allResources returns all three resources")
    func allResources() {
        let all = CrisisResource.allResources

        #expect(all.count == 3)
    }

    @Test("Phone URLs are valid for resources with phone numbers")
    func phoneURLsValid() {
        let lifeline = CrisisResource.suicideCrisisLifeline
        #expect(lifeline.phoneURL != nil)
        #expect(lifeline.phoneURL?.scheme == "tel")

        let emergency = CrisisResource.emergency911
        #expect(emergency.phoneURL != nil)
        #expect(emergency.phoneURL?.scheme == "tel")
    }

    @Test("SMS URL is valid for Crisis Text Line")
    func smsURLValid() {
        let textLine = CrisisResource.crisisTextLine
        #expect(textLine.smsURL != nil)
        #expect(textLine.smsURL?.scheme == "sms")
    }
}

// MARK: - Crisis Colors Tests (Task 6)

@Suite("Crisis Colors Tests")
@MainActor
struct CrisisColorsTests {

    @Test("Crisis surface color exists")
    func crisisSurfaceExists() {
        _ = Color.crisisSurface
    }

    @Test("Crisis accent color exists")
    func crisisAccentExists() {
        _ = Color.crisisAccent
    }

    @Test("Crisis surface dark variant exists")
    func crisisSurfaceDarkExists() {
        _ = Color.crisisSurfaceDark
    }

    @Test("Crisis accent dark variant exists")
    func crisisAccentDarkExists() {
        _ = Color.crisisAccentDark
    }

    @Test("Adaptive crisis surface returns correct color for light mode")
    func adaptiveCrisisSurfaceLight() {
        let color = Color.adaptiveCrisisSurface(.light)
        #expect(color == Color.crisisSurface)
    }

    @Test("Adaptive crisis surface returns correct color for dark mode")
    func adaptiveCrisisSurfaceDark() {
        let color = Color.adaptiveCrisisSurface(.dark)
        #expect(color == Color.crisisSurfaceDark)
    }

    @Test("Adaptive crisis accent returns correct color for light mode")
    func adaptiveCrisisAccentLight() {
        let color = Color.adaptiveCrisisAccent(.light)
        #expect(color == Color.crisisAccent)
    }

    @Test("Adaptive crisis accent returns correct color for dark mode")
    func adaptiveCrisisAccentDark() {
        let color = Color.adaptiveCrisisAccent(.dark)
        #expect(color == Color.crisisAccentDark)
    }

    @Test("Crisis surface is warm, not red/error colored")
    func crisisSurfaceIsWarm() {
        // Crisis surface should be distinct from error/warning colors
        #expect(Color.crisisSurface != Color.terracotta)
        #expect(Color.crisisSurface != Color.warningAmber)
    }

    @Test("Crisis colors are distinct from semantic error colors")
    func crisisColorsDistinct() {
        #expect(Color.crisisAccent != Color.terracotta)
        #expect(Color.crisisSurface != Color.cream)
    }
}
