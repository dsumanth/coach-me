//
//  Typography.swift
//  CoachMe
//
//  Created by Dev Agent on 2/6/26.
//

import SwiftUI

/// Typography system with Dynamic Type support
/// Per UX spec: Friendly and readable, not technical or trendy
/// Uses SF Rounded for headlines/titles, SF Pro for body text
enum Typography {
    // MARK: - Display Styles

    /// Large display text for welcome screens - 34pt bold rounded
    static let display = Font.system(size: 34, weight: .bold, design: .rounded)

    /// Section titles - 28pt semibold rounded
    static let title = Font.system(size: 28, weight: .semibold, design: .rounded)

    /// Subsection titles - 22pt semibold rounded
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)

    /// Card titles, sheet headers - 17pt semibold rounded
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)

    // MARK: - Body Styles

    /// Primary body text - conversations, descriptions - 17pt regular
    static let body = Font.system(size: 17, weight: .regular, design: .default)

    /// Emphasized body text - 17pt medium
    static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)

    /// Secondary text - timestamps, metadata - 15pt regular
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)

    /// Callout text - 16pt regular
    static let callout = Font.system(size: 16, weight: .regular, design: .default)

    // MARK: - Small Styles

    /// Secondary text - timestamps, metadata - 13pt regular
    static let caption = Font.system(size: 13, weight: .regular, design: .default)

    /// Small caption - 11pt regular
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)

    /// Small labels - badges, hints - 11pt medium
    static let footnote = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - Dynamic Type Scaling Variants
    //
    // NOTE: Scaled variants use SwiftUI's semantic text styles (.body, .headline, etc.)
    // which provide proper Dynamic Type accessibility scaling. These use SF Pro (default
    // design) rather than SF Rounded, as Apple HIG recommends SF Pro for body text
    // readability. The rounded design is reserved for display/headline styles above.

    /// Body text with Dynamic Type scaling and loose leading
    static var bodyScaled: Font {
        .body.leading(.loose)
    }

    /// Caption with Dynamic Type scaling
    static var captionScaled: Font {
        .caption
    }

    /// Headline with Dynamic Type scaling
    static var headlineScaled: Font {
        .headline
    }

    /// Title with Dynamic Type scaling
    static var titleScaled: Font {
        .title2
    }

    // MARK: - Semantic Text Styles

    /// Empty state titles - warm and inviting - 20pt semibold rounded
    static let emptyStateTitle = Font.system(size: 20, weight: .semibold, design: .rounded)

    /// Conversation message text - optimized for reading
    static let message = Font.system(size: 17, weight: .regular, design: .default)

    /// Input field placeholder text
    static let placeholder = Font.system(size: 17, weight: .regular, design: .default)

    /// Button labels
    static let button = Font.system(size: 17, weight: .semibold, design: .rounded)

    /// Navigation bar titles
    static let navTitle = Font.system(size: 17, weight: .semibold, design: .rounded)

    /// Tab bar labels
    static let tabLabel = Font.system(size: 10, weight: .medium, design: .default)

    /// Error messages - warm tone
    static let errorMessage = Font.system(size: 15, weight: .regular, design: .default)
}

// MARK: - Preview

#Preview("Typography Styles") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Display").font(Typography.display)
                Text("Title").font(Typography.title)
                Text("Title 2").font(Typography.title2)
                Text("Headline").font(Typography.headline)
            }

            Divider()

            Group {
                Text("Body").font(Typography.body)
                Text("Body Medium").font(Typography.bodyMedium)
                Text("Subheadline").font(Typography.subheadline)
                Text("Callout").font(Typography.callout)
            }

            Divider()

            Group {
                Text("Caption").font(Typography.caption)
                Text("Caption 2").font(Typography.caption2)
                Text("Footnote").font(Typography.footnote)
            }

            Divider()

            Group {
                Text("Message").font(Typography.message)
                Text("Button").font(Typography.button)
                Text("Error Message").font(Typography.errorMessage)
            }
        }
        .padding()
    }
    .background(Color.cream)
}
