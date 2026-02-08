# Story 4.2: Crisis Resource Display

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user in distress**,
I want **to see crisis resources presented with empathy when crisis indicators are detected**,
so that **I feel supported and cared for, not dismissed or handled by a system**.

## Acceptance Criteria

1. **Given** crisis is detected in the streaming response, **When** the response appears, **Then** a warm adaptive sheet slides in with an empathetic message and crisis resources (FR17, UX-6).

2. **Given** the crisis resource sheet is displayed, **When** I see the content, **Then** I see 988 Suicide & Crisis Lifeline (tap-to-call) and Crisis Text Line (tap-to-text HOME to 741741) with clear, tappable actions.

3. **Given** I want to continue coaching, **When** I dismiss the crisis resource sheet, **Then** I can continue the conversation without awkwardness (the sheet does not block normal usage).

4. **Given** the crisis sheet is displayed, **When** VoiceOver is active, **Then** all resources are fully accessible with descriptive labels (e.g., "Call 988 Suicide and Crisis Lifeline, available 24/7").

5. **Given** the app is running on any supported iOS version, **When** the crisis sheet appears, **Then** it uses adaptive styling (Liquid Glass on iOS 26+, Warm Modern on iOS 18-25) consistent with the design system.

## Tasks / Subtasks

- [ ] Task 1: Create CrisisResource data model and constants (AC: #2)
  - [ ] 1.1 Create `Features/Safety/Models/CrisisResources.swift` with `CrisisResource` struct
  - [ ] 1.2 Define static resources: 988 Suicide & Crisis Lifeline, Crisis Text Line
  - [ ] 1.3 Add emergency fallback: 911 for immediate danger
  - [ ] 1.4 Include `tel:`, `sms:`, and web URL properties for each resource

- [ ] Task 2: Create CrisisResourceSheet view (AC: #1, #3, #5)
  - [ ] 2.1 Create `Features/Safety/Views/CrisisResourceSheet.swift`
  - [ ] 2.2 Implement empathetic header copy: "I hear you, and what you're feeling sounds really heavy."
  - [ ] 2.3 Implement honest boundary copy: "This is beyond what I can help with as a coaching tool."
  - [ ] 2.4 Render tappable resource cards with phone and text actions
  - [ ] 2.5 Implement gentle close copy: "I'm here for coaching when you're ready."
  - [ ] 2.6 Apply adaptive styling using existing `LiquidPanelModifier` / `.adaptiveGlass()` patterns
  - [ ] 2.7 Use `crisis-subtle` warm background (#FED7AA light / warm dark equivalent)

- [ ] Task 3: Wire crisis detection flag from backend to sheet display (AC: #1)
  - [ ] 3.1 Add `crisis_detected` field to SSE streaming events in `chat-stream/index.ts`
  - [ ] 3.2 Create `crisis-detector.ts` helper in `_shared/` with keyword + pattern matching
  - [ ] 3.3 Call crisis detector BEFORE LLM call in the chat-stream pipeline
  - [ ] 3.4 Update `ChatStreamService.swift` to parse `crisis_detected` flag from SSE events
  - [ ] 3.5 Add `showCrisisResources` state to `ChatViewModel.swift`
  - [ ] 3.6 Add `.sheet(isPresented:)` modifier to `ChatView.swift` for crisis resource sheet

- [ ] Task 4: Implement tap-to-call/text functionality (AC: #2)
  - [ ] 4.1 Implement `openURL` for phone calls (e.g., `tel:988`)
  - [ ] 4.2 Implement `openURL` for text messages (e.g., `sms:741741&body=HELLO`)
  - [ ] 4.3 Handle fallback for devices without phone capability (show number as text)

- [ ] Task 5: Accessibility (AC: #4)
  - [ ] 5.1 Add `.accessibilityLabel` and `.accessibilityHint` to all resource cards
  - [ ] 5.2 Add `.accessibilityAddTraits(.isModal)` to the crisis sheet
  - [ ] 5.3 Ensure Dynamic Type support at all text sizes
  - [ ] 5.4 Test with VoiceOver navigation order

- [ ] Task 6: Add crisis-specific colors to design system (AC: #5)
  - [ ] 6.1 Add `crisisSurface` and `crisisAccent` to `Colors.swift` (use UX spec colors: #FED7AA light, deep sienna accent)

## Dev Notes

### Critical Context: Crisis UX Design Philosophy

**Target emotion: "Held, not handled."** The user must feel CARED FOR, not processed by a system. This is the single most important design decision in this story. Reference: [ux-design-specification.md — Crisis Handling Flow, line 1018-1060].

**Crisis Design Principles (from UX spec):**

| Principle | Implementation |
|---|---|
| Held, not handled | Empathetic language FIRST, before any resources |
| Honest boundary | "This is beyond what I can help with as a coaching tool" — clear but gentle |
| Resources, not rejection | Warm container, clear info — help without abandonment |
| Door stays open | "I'm here for coaching when you're ready" — crisis doesn't end the relationship |
| No shame on return | Story 4.5 handles this — normal coaching resumes |

### Architecture Compliance

**Pattern: MVVM + Repository.** This story adds a new feature module under `Features/Safety/`. Follow the existing module pattern:
```
Features/Safety/
├── Models/
│   └── CrisisResources.swift
├── Views/
│   └── CrisisResourceSheet.swift
└── Services/
    └── (CrisisDetectionService.swift — only if client-side fallback needed)
```

**CRITICAL: Use adaptive design system modifiers.** Never use raw `.glassEffect()`. Always use `.adaptiveGlass()` or `AdaptiveGlassContainer`. Reference: [architecture.md — Enforcement Guidelines].

**Sheet presentation pattern:** Follow the exact pattern used in `ChatView.swift` for existing sheets. The ContextPromptSheet overlay (lines 284-313 in ChatView.swift) is the closest reference — it uses a `GeometryReader` with `ZStack` and warm backdrop. However, for consistency with other sheets, use the standard `.sheet(isPresented:)` modifier with `.presentationDetents([.medium, .large])`.

### Existing Code to Extend (NOT Reinvent)

**ChatViewModel.swift** — Add a `@Published var showCrisisResources = false` property. When the streaming response includes `crisis_detected: true`, set this flag. Location: near line 42-45 where `currentResponseHasMemoryMoments` and `currentResponseHasPatternInsights` are tracked.

**ChatView.swift** — Add a new `.sheet(isPresented:)` modifier for the crisis resource sheet. Location: near the existing sheet modifiers at lines 115-201. Add an `.onChange(of:)` observer for the crisis flag, similar to how memory moments/pattern insights are tracked.

**chat-stream/index.ts** — The crisis detection must run BEFORE the LLM call (line ~108, after history loading but before `buildCoachingPrompt`). If crisis is detected, still make the LLM call but inject a crisis-handling instruction into the system prompt AND send a `crisis_detected: true` flag in the first SSE event.

**prompt-builder.ts** — The base prompt at line 53 already says "If users mention crisis indicators (self-harm, suicide), acknowledge their feelings and encourage professional help." Story 4.2 ENHANCES this with structured detection and resource display rather than relying solely on the LLM's judgment.

### Colors & Styling

**From UX specification:**
- `crisis-subtle` background: `#FED7AA` (warm peach-orange) in light mode
- `crisis` accent: `#7C2D12` (deep sienna) for emphasis text
- Dark mode: Use existing warm dark surface tones, not pure black

**Add to Colors.swift:**
```swift
static let crisisSurface = Color(red: 254/255, green: 215/255, blue: 170/255) // #FED7AA
static let crisisAccent = Color(red: 124/255, green: 45/255, blue: 18/255)   // #7C2D12
// Dark mode variants should use the existing warm dark palette
```

### Crisis Resources Data

```swift
struct CrisisResource: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let phoneNumber: String?  // For tel: links
    let textNumber: String?   // For sms: links
    let textBody: String?     // Pre-filled SMS body
    let availability: String
}

// Constants:
// 1. 988 Suicide & Crisis Lifeline — Phone: "988", Available: "24/7"
// 2. Crisis Text Line — Text: "741741", Body: "HELLO", Available: "24/7"
// 3. Emergency: 911 (for immediate danger)
```

### Backend: Crisis Detection Pipeline

**Create `_shared/crisis-detector.ts`:**
- Keyword matching for crisis indicators: self-harm, suicidal ideation, abuse, severe distress
- Pattern: export a `detectCrisis(message: string): { detected: boolean; severity: string }` function
- Run BEFORE LLM call in chat-stream pipeline
- Return `crisis_detected` flag in first SSE event so client can show sheet immediately

**SSE event format extension:**
```typescript
// New event sent before streaming begins (if crisis detected):
data: {"type": "crisis_detected", "severity": "high"}

// Existing events continue normally after:
data: {"type": "token", "content": "...", "memory_moment": false, "pattern_insight": false}
```

**iOS streaming client update — parse new event type:**
```swift
// In ChatStreamService or wherever SSE events are parsed:
case "crisis_detected":
    // Notify ViewModel to show crisis sheet
```

### Empathetic Copy (From UX Spec)

**Header:** "I hear you, and what you're feeling sounds really heavy."
**Boundary:** "This is beyond what I can help with as a coaching tool, but there are people who can help right now."
**Resource intro:** "You can reach out to:"
**Close:** "I'm here for coaching when you're ready to come back."

**CRITICAL: Do NOT use clinical/system language.** No "Crisis detected", no "Emergency resources", no "alert" framing. Use warm, first-person, empathetic language per UX-11.

### Dependency: Story 4.1 (Crisis Detection Pipeline)

Story 4.1 covers the full server-side crisis detection pipeline. This story (4.2) can be developed in parallel — build the UI and wire it to a `crisis_detected` flag. For testing without 4.1, you can temporarily trigger the crisis sheet with a hardcoded test button or by detecting specific test keywords client-side.

### Anti-Patterns to Avoid

- **DO NOT** use system alert / UIAlertController — too cold and robotic
- **DO NOT** make the sheet undismissable — users must have autonomy (UX principle: "Gentle Over Aggressive")
- **DO NOT** use red/warning colors — use warm crisis-subtle (#FED7AA), not error red
- **DO NOT** log user messages that triggered crisis detection (no PII in logs)
- **DO NOT** apply `.glassEffect()` directly — use `.adaptiveGlass()` modifiers
- **DO NOT** put crisis resources as inline chat content — use a sheet overlay for appropriate emphasis
- **DO NOT** create duplicate phone/URL handling — use `UIApplication.shared.open(url)`

### Testing Guidance

**Manual test scenarios:**
1. Send message with crisis keywords → verify sheet appears with correct resources
2. Tap phone number → verify `tel:988` link opens
3. Tap text link → verify `sms:741741&body=HELLO` opens Messages
4. Dismiss sheet → verify conversation continues normally
5. Test with VoiceOver → verify all resources announced correctly
6. Test on iOS 18 simulator → verify Warm Modern styling
7. Test with Dynamic Type at largest size → verify layout doesn't break

**Unit tests to write:**
- `CrisisResourceTests` — verify resource constants are correct
- `CrisisDetectorTests` — verify keyword detection accuracy
- `CrisisResourceSheetTests` — verify view renders with correct content

### Project Structure Notes

- New files go in `Features/Safety/` which already exists as an empty directory
- Follow the established module pattern: `Models/`, `Views/`, `Services/` subdirectories
- `CrisisResources.swift` in `Models/` — data model and constants
- `CrisisResourceSheet.swift` in `Views/` — the main UI component
- Architecture specifies `Core/Constants/CrisisResources.swift` but since this is feature-specific, keep in `Features/Safety/Models/` to match the module pattern used elsewhere (e.g., Context profile in Features/Context/Models/)

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — Features/Safety/ directory structure]
- [Source: _bmad-output/planning-artifacts/architecture.md — Enforcement Guidelines, Anti-Patterns]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Flow — Coaching Conversation pipeline showing crisis-detector.ts placement]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Crisis Handling Flow, lines 1018-1060]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — CrisisBanner component spec, line 1302-1311]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Crisis colors: #7C2D12, #FED7AA, line 689-690]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — Emotional Journey: Crisis boundary → "Held, cared for", line 189]
- [Source: _bmad-output/planning-artifacts/epics.md — Story 4.2 acceptance criteria, lines 1009-1033]
- [Source: CoachMe/Features/Chat/Views/ChatView.swift — existing sheet patterns, lines 115-201]
- [Source: CoachMe/Features/Context/Views/ContextPromptSheet.swift — empathetic sheet template]
- [Source: CoachMe/Supabase/supabase/functions/chat-stream/index.ts — streaming pipeline]
- [Source: CoachMe/Supabase/supabase/functions/_shared/prompt-builder.ts — existing crisis prompt line 53]
- [Source: CoachMe/Features/Chat/ViewModels/ChatViewModel.swift — memory/pattern flag tracking, lines 42-45]
- [Source: CoachMe/Core/UI/Theme/Colors.swift — warm color palette]

## Dev Agent Record

### Agent Model Used

(To be filled by dev agent)

### Debug Log References

### Completion Notes List

### File List
