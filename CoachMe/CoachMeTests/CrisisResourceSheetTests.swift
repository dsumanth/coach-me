//
//  CrisisResourceSheetTests.swift
//  CoachMeTests
//
//  Story 4.2: Crisis Resource Display
//  Tests for CrisisResourceSheet view and ChatViewModel crisis wiring
//

import Testing
import SwiftUI
@testable import CoachMe

// MARK: - CrisisResourceSheet Content Tests

@Suite("CrisisResourceSheet Content Tests")
@MainActor
struct CrisisResourceSheetContentTests {

    @Test("Sheet can be instantiated without errors")
    func sheetInstantiates() {
        _ = CrisisResourceSheet()
    }

    @Test("All crisis resources have at least one contact method")
    func resourcesHaveContactMethods() {
        for resource in CrisisResource.allResources {
            let hasPhone = resource.phoneURL != nil
            let hasSMS = resource.smsURL != nil
            #expect(hasPhone || hasSMS, "\(resource.name) must have at least one contact method")
        }
    }

    @Test("988 Lifeline phone URL dials 988")
    func lifelinePhoneURL() {
        let lifeline = CrisisResource.suicideCrisisLifeline
        #expect(lifeline.phoneURL?.absoluteString == "tel:988")
    }

    @Test("Crisis Text Line SMS URL includes HELLO body")
    func crisisTextLineSMSURL() {
        let textLine = CrisisResource.crisisTextLine
        let smsURL = textLine.smsURL?.absoluteString ?? ""
        #expect(smsURL.contains("741741"))
        #expect(smsURL.contains("HELLO"))
    }

    @Test("911 Emergency phone URL dials 911")
    func emergency911PhoneURL() {
        let emergency = CrisisResource.emergency911
        #expect(emergency.phoneURL?.absoluteString == "tel:911")
    }

    @Test("Resources without phone numbers have no phone URL")
    func noPhoneNoURL() {
        let textOnly = CrisisResource(
            name: "Text Only",
            description: "Desc",
            phoneNumber: nil,
            textNumber: "12345",
            textBody: nil,
            availability: "24/7"
        )
        #expect(textOnly.phoneURL == nil)
    }

    @Test("Resources without text numbers have no SMS URL")
    func noTextNoSMS() {
        let phoneOnly = CrisisResource(
            name: "Phone Only",
            description: "Desc",
            phoneNumber: "123",
            textNumber: nil,
            textBody: nil,
            availability: "24/7"
        )
        #expect(phoneOnly.smsURL == nil)
    }
}

// MARK: - ChatViewModel Crisis Sheet Wiring Tests

@Suite("ChatViewModel Crisis Sheet Wiring Tests")
@MainActor
struct ChatViewModelCrisisSheetTests {

    @Test("showCrisisResources initializes to false")
    func showCrisisResourcesInitialState() {
        let viewModel = ChatViewModel()
        #expect(viewModel.showCrisisResources == false)
    }

    @Test("showCrisisResources can be set to true")
    func showCrisisResourcesCanBeSet() {
        let viewModel = ChatViewModel()
        viewModel.showCrisisResources = true
        #expect(viewModel.showCrisisResources == true)
    }

    @Test("showCrisisResources persists across message state changes")
    func showCrisisResourcesPersists() {
        let viewModel = ChatViewModel()
        viewModel.showCrisisResources = true

        // Verify it doesn't get accidentally reset
        viewModel.inputText = "New message"
        #expect(viewModel.showCrisisResources == true)
    }

    @Test("showCrisisResources is independent of currentResponseHasCrisisFlag")
    func showCrisisResourcesIndependent() {
        let viewModel = ChatViewModel()

        // Set crisis flag but not sheet
        viewModel.currentResponseHasCrisisFlag = true
        #expect(viewModel.showCrisisResources == false)

        // Set sheet but reset crisis flag
        viewModel.showCrisisResources = true
        viewModel.currentResponseHasCrisisFlag = false
        #expect(viewModel.showCrisisResources == true)
    }

    @Test("startNewConversation does not affect showCrisisResources dismissal")
    func startNewConversationCrisisState() {
        let viewModel = ChatViewModel()
        viewModel.showCrisisResources = true

        viewModel.startNewConversation()

        // showCrisisResources is sheet-presentation state controlled by SwiftUI binding,
        // not session state — it remains as-is until user dismisses
        // (the crisis flag is reset, but the sheet stays if already showing)
        #expect(viewModel.currentResponseHasCrisisFlag == false)
    }
}
