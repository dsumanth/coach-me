import Foundation
import CoreGraphics
import CoreText

let outputPath = "output/pdf/coachme_app_summary.pdf"
let pageWidth: CGFloat = 612
let pageHeight: CGFloat = 792
let margin: CGFloat = 42
let contentWidth = pageWidth - (margin * 2)

func makeFont(_ name: String, _ size: CGFloat) -> CTFont {
    CTFontCreateWithName(name as CFString, size, nil)
}

let titleFont = makeFont("Helvetica-Bold", 20)
let headingFont = makeFont("Helvetica-Bold", 12.5)
let bodyFont = makeFont("Helvetica", 10.5)
let smallFont = makeFont("Helvetica", 10)

func paragraphStyle(firstLine: CGFloat = 0, head: CGFloat = 0, spacing: CGFloat = 2.0) -> CTParagraphStyle {
    var first = firstLine
    var rest = head
    var lineSpace = spacing
    var alignment = CTTextAlignment.left

    let settings = [
        CTParagraphStyleSetting(spec: .firstLineHeadIndent, valueSize: MemoryLayout<CGFloat>.size, value: &first),
        CTParagraphStyleSetting(spec: .headIndent, valueSize: MemoryLayout<CGFloat>.size, value: &rest),
        CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: &lineSpace),
        CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &alignment)
    ]

    return CTParagraphStyleCreate(settings, settings.count)
}

func attributed(_ text: String, font: CTFont, paragraph: CTParagraphStyle) -> NSAttributedString {
    NSAttributedString(
        string: text,
        attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraph,
            kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0.1, alpha: 1.0)
        ]
    )
}

func drawText(_ text: String,
              font: CTFont,
              x: CGFloat,
              yTop: CGFloat,
              width: CGFloat,
              context: CGContext,
              firstLineIndent: CGFloat = 0,
              headIndent: CGFloat = 0,
              lineSpacing: CGFloat = 2.0,
              after: CGFloat = 6) -> CGFloat {
    let para = paragraphStyle(firstLine: firstLineIndent, head: headIndent, spacing: lineSpacing)
    let attr = attributed(text, font: font, paragraph: para)
    let framesetter = CTFramesetterCreateWithAttributedString(attr as CFAttributedString)
    let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
        framesetter,
        CFRange(location: 0, length: attr.length),
        nil,
        CGSize(width: width, height: .greatestFiniteMagnitude),
        nil
    )
    let h = ceil(suggested.height)

    let rect = CGRect(x: x, y: pageHeight - yTop - h, width: width, height: h)
    let path = CGPath(rect: rect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attr.length), path, nil)
    CTFrameDraw(frame, context)

    return h + after
}

let url = URL(fileURLWithPath: outputPath)
FileManager.default.createFile(atPath: outputPath, contents: nil)

var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
    fputs("Failed to create PDF context at \(outputPath)\n", stderr)
    exit(1)
}

context.beginPDFPage(nil)

var y = margin

y += drawText("CoachMe App Summary", font: titleFont, x: margin, yTop: y, width: contentWidth, context: context, lineSpacing: 1.0, after: 10)

y += drawText("WHAT IT IS", font: headingFont, x: margin, yTop: y, width: contentWidth, context: context, lineSpacing: 1.0, after: 4)
y += drawText("CoachMe is a SwiftUI iOS app for personal AI coaching through a chat-first experience. It uses Supabase for auth/data, streams assistant responses from Edge Functions, and keeps local SwiftData cache for offline continuity.", font: bodyFont, x: margin, yTop: y, width: contentWidth, context: context, after: 8)

y += drawText("WHO IT IS FOR", font: headingFont, x: margin, yTop: y, width: contentWidth, context: context, lineSpacing: 1.0, after: 4)
y += drawText("Primary persona (inferred from WelcomeView text and domain config files): people who want ongoing coaching support across life, career, relationships, mindset, leadership, creativity, and fitness.", font: bodyFont, x: margin, yTop: y, width: contentWidth, context: context, after: 8)

y += drawText("WHAT IT DOES", font: headingFont, x: margin, yTop: y, width: contentWidth, context: context, lineSpacing: 1.0, after: 4)

let features = [
    "- Sign in with Apple authentication with session restore and Supabase-backed user identity.",
    "- Real-time streaming chat (SSE) with conversation history persistence.",
    "- Voice-to-text message input using Speech and microphone permissions.",
    "- Context profile setup/editing plus extracted insights from conversations.",
    "- Conversation list/history with local cache and automatic sync when connectivity returns.",
    "- Safety flow with crisis signal detection and in-app crisis resource sheet.",
    "- RevenueCat-based trial/subscription gating and personalized onboarding paywall flow."
]

for item in features {
    y += drawText(item, font: bodyFont, x: margin, yTop: y, width: contentWidth, context: context, firstLineIndent: 0, headIndent: 14, after: 2)
}

y += 6
y += drawText("HOW IT WORKS (ARCHITECTURE)", font: headingFont, x: margin, yTop: y, width: contentWidth, context: context, lineSpacing: 1.0, after: 4)

let architecture = [
    "- Client: SwiftUI app (RootView, ChatViewModel, services) talks to Supabase Auth and Postgres via Supabase Swift SDK.",
    "- Chat path: ChatViewModel -> ChatStreamService -> /functions/v1/chat-stream (SSE) -> shared modules (context-loader, domain-router, prompt-builder, llm-client) -> model provider -> streamed tokens back to iOS.",
    "- Data path: ConversationService and ContextRepository read/write tables such as users, conversations, messages, context_profiles, push_tokens, and scheduled_reminders (per migrations/README).",
    "- Reliability/push path: OfflineCacheService + OfflineSyncService handle local cache/conflict sync; push-trigger orchestrates reminders and calls push-send, which delivers through APNs."
]

for item in architecture {
    y += drawText(item, font: smallFont, x: margin, yTop: y, width: contentWidth, context: context, firstLineIndent: 0, headIndent: 14, after: 2)
}

y += 6
y += drawText("HOW TO RUN (MINIMAL)", font: headingFont, x: margin, yTop: y, width: contentWidth, context: context, lineSpacing: 1.0, after: 4)

let runSteps = [
    "1. Copy Config.xcconfig.template to Debug.xcconfig and Release.xcconfig, then fill SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, and REVENUECAT_API_KEY.",
    "2. Open CoachMe.xcodeproj in Xcode, select the CoachMe scheme (Debug), and run on an iOS simulator or device.",
    "3. For new backend environments, Supabase/README indicates linking your project and running: supabase db push.",
    "4. Full local Supabase Edge runtime bootstrapping steps: Not found in repo."
]

for step in runSteps {
    y += drawText(step, font: smallFont, x: margin, yTop: y, width: contentWidth, context: context, firstLineIndent: 0, headIndent: 14, after: 2)
}

if y > pageHeight - margin {
    fputs("Warning: content exceeded one-page layout budget (y=\(y)).\n", stderr)
}

context.endPDFPage()
context.closePDF()

print(outputPath)
