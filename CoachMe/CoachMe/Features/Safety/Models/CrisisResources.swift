//
//  CrisisResources.swift
//  CoachMe
//
//  Story 4.2: Crisis Resource Display
//  Data model and constants for crisis support resources.
//  Target emotion: "Held, not handled."
//

import Foundation

/// A crisis support resource with contact information
struct CrisisResource: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let phoneNumber: String?
    let textNumber: String?
    let textBody: String?
    let availability: String

    /// URL for initiating a phone call
    var phoneURL: URL? {
        guard let phone = phoneNumber else { return nil }
        return URL(string: "tel:\(phone)")
    }

    /// URL for initiating an SMS message
    var smsURL: URL? {
        guard let number = textNumber else { return nil }
        if let body = textBody,
           let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "sms:\(number)?body=\(encodedBody)")
        }
        return URL(string: "sms:\(number)")
    }
}

// MARK: - Static Resources

extension CrisisResource {

    /// 988 Suicide & Crisis Lifeline — call or text 988
    static let suicideCrisisLifeline = CrisisResource(
        name: "988 Suicide & Crisis Lifeline",
        description: "Free, confidential support for people in distress",
        phoneNumber: "988",
        textNumber: "988",
        textBody: nil,
        availability: "24/7"
    )

    /// Crisis Text Line — text HOME to 741741
    static let crisisTextLine = CrisisResource(
        name: "Crisis Text Line",
        description: "Text with a trained crisis counselor",
        phoneNumber: nil,
        textNumber: "741741",
        textBody: "HELLO",
        availability: "24/7"
    )

    /// Emergency 911 — for immediate danger
    static let emergency911 = CrisisResource(
        name: "911 Emergency",
        description: "For immediate danger to yourself or others",
        phoneNumber: "911",
        textNumber: nil,
        textBody: nil,
        availability: "24/7"
    )

    /// All available crisis resources in display order
    static let allResources: [CrisisResource] = [
        .suicideCrisisLifeline,
        .crisisTextLine,
        .emergency911,
    ]
}
