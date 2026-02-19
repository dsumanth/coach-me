//
//  ContextProfileView.swift
//  CoachMe
//
//  Story 2.5: Context Profile Viewing & Editing
//  Main view for displaying and editing the user's context profile
//  Per architecture.md: Use adaptive design modifiers, VoiceOver accessibility
//

import SwiftUI

/// Main view displaying the user's context profile with values, goals, and situation
/// Uses warm framing with "Here's how I see you" personality
struct ContextProfileView: View {
    // MARK: - Properties

    /// The authenticated user's ID
    let userId: UUID

    // MARK: - State

    @State private var viewModel = ContextViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignConstants.Spacing.xl) {
                    // Warm header
                    headerSection

                    if viewModel.isLoading {
                        loadingView
                    } else if let profile = viewModel.profile {
                        // Profile sections
                        valuesSection(profile.values)
                        goalsSection(profile.goals)
                        situationSection(profile.situation)

                        // Story 11.4: Discovery session data
                        if profile.hasDiscoveryData {
                            discoverySection(profile)
                        }

                        // Story 8.8: Learned knowledge section
                        LearnedKnowledgeSection(
                            patterns: viewModel.inferredPatterns,
                            effectiveStyle: viewModel.effectiveCoachingStyle,
                            hasManualOverride: viewModel.hasManualStyleOverride,
                            domainUsage: viewModel.domainUsage,
                            progressNotes: viewModel.progressNotes,
                            hasLearnedKnowledge: viewModel.hasLearnedKnowledge,
                            onDismissInsight: { id in
                                viewModel.deletingLearnedItemId = id
                                viewModel.showDeleteLearnedConfirmation = true
                            },
                            onEditStyle: {
                                viewModel.showStyleOverrideSheet = true
                            }
                        )
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, DesignConstants.Spacing.lg)
                .padding(.bottom, DesignConstants.Spacing.xxl)
            }
            .background(Color.adaptiveCream(colorScheme).ignoresSafeArea())
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.terracotta)
                }

                if viewModel.isSaving {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                            .tint(Color.terracotta)
                    }
                }
            }
            .refreshable {
                await viewModel.refreshProfile()
            }
            .task {
                await viewModel.loadProfile(userId: userId)
            }
            .sheet(item: $viewModel.editingItem) { item in
                ContextEditorSheet(
                    editItem: item,
                    onSave: { newContent in
                        Task {
                            await handleSave(item: item, newContent: newContent)
                        }
                    },
                    onCancel: {
                        viewModel.cancelEdit()
                    }
                )
            }
            .alert("Remove this from your profile?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Keep it", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("Remove", role: .destructive) {
                    Task {
                        await viewModel.confirmDelete()
                    }
                }
            } message: {
                Text("I'll forget this detail about you. You can always share it again later.")
            }
            .alert("Oops", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.error?.errorDescription ?? "Something went wrong. Please try again.")
            }
            // Story 8.8: Learned insight delete confirmation
            .confirmationDialog(
                "Remove this insight?",
                isPresented: $viewModel.showDeleteLearnedConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let id = viewModel.deletingLearnedItemId {
                        Task { await viewModel.dismissLearnedInsight(id: id) }
                    }
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("This won't be suggested again.")
            }
            // Story 8.8: Style override sheet
            .sheet(isPresented: $viewModel.showStyleOverrideSheet) {
                StyleOverrideSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
            Text("Here's how I see you")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("This is what I remember about you from our conversations. You can edit or remove anything here.")
                .font(.subheadline)
                .foregroundStyle(Color.warmGray500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignConstants.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Here's how I see you. This is what I remember about you from our conversations. You can edit or remove anything here.")
    }

    // MARK: - Values Section

    @ViewBuilder
    private func valuesSection(_ values: [ContextValue]) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            sectionHeader(
                title: "What Matters to You",
                icon: "heart.fill",
                color: .terracotta
            )

            if values.isEmpty {
                emptySectionCard(
                    message: "I haven't learned what matters most to you yet. Share your values in our conversations, and I'll remember them here.",
                    icon: "heart"
                )
            } else {
                ForEach(values) { value in
                    ContextItemRow.value(
                        value,
                        onEdit: { viewModel.startEditingValue(id: value.id) },
                        onDelete: { viewModel.requestDeleteValue(id: value.id) }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Values section. \(values.count) items.")
    }

    // MARK: - Goals Section

    @ViewBuilder
    private func goalsSection(_ goals: [ContextGoal]) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            sectionHeader(
                title: "What You're Working Toward",
                icon: "target",
                color: .sage
            )

            if goals.isEmpty {
                emptySectionCard(
                    message: "I don't know your goals yet. Tell me what you're working toward, and I'll keep track here.",
                    icon: "target"
                )
            } else {
                // Active goals first, then achieved
                let activeGoals = goals.filter { $0.status == .active }
                let achievedGoals = goals.filter { $0.status == .achieved }

                ForEach(activeGoals) { goal in
                    goalRow(goal)
                }

                if !achievedGoals.isEmpty {
                    Text("Completed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.warmGray400)
                        .padding(.top, DesignConstants.Spacing.xs)

                    ForEach(achievedGoals) { goal in
                        goalRow(goal)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Goals section. \(goals.count) items.")
    }

    private func goalRow(_ goal: ContextGoal) -> some View {
        HStack(spacing: DesignConstants.Spacing.xs) {
            // Toggle status button (before the row)
            Button {
                Task {
                    await viewModel.toggleGoalStatus(id: goal.id)
                }
            } label: {
                Image(systemName: goal.status == .achieved ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(goal.status == .achieved ? Color.successGreen : Color.warmGray300)
                    .frame(width: DesignConstants.Size.minTouchTarget, height: DesignConstants.Size.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(goal.status == .achieved ? "Mark as active" : "Mark as achieved")
            .accessibilityHint(goal.status == .achieved ? "Double tap to reactivate this goal" : "Double tap to mark this goal as achieved")

            // Goal content and actions
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xxs) {
                Text(goal.content)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .strikethrough(goal.status == .achieved, color: Color.warmGray400)
                    .lineLimit(3)

                if goal.status == .achieved {
                    Text("achieved")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.successGreen)
                }
            }

            Spacer(minLength: DesignConstants.Spacing.xs)

            // Edit button
            Button {
                viewModel.startEditingGoal(id: goal.id)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.warmGray400)
                    .frame(width: DesignConstants.Size.minTouchTarget, height: DesignConstants.Size.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit")
            .accessibilityHint("Opens editor for this goal")

            // Delete button
            Button {
                viewModel.requestDeleteGoal(id: goal.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.warmGray400)
                    .frame(width: DesignConstants.Size.minTouchTarget, height: DesignConstants.Size.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
            .accessibilityHint("Removes this goal from your profile")
        }
        .padding(.vertical, DesignConstants.Spacing.sm)
        .padding(.horizontal, DesignConstants.Spacing.md)
        .modifier(ContextProfileRowSurfaceModifier(colorScheme: colorScheme))
    }

    // MARK: - Situation Section

    @ViewBuilder
    private func situationSection(_ situation: ContextSituation) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            sectionHeader(
                title: "About Your Life",
                icon: "person.fill",
                color: .dustyRose
            )

            if !situation.hasContent {
                emptySectionCard(
                    message: "I haven't learned about your life situation yet. Share what's going on in your life, and I'll remember it here.",
                    icon: "person"
                )
            } else {
                situationCard(situation)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Life situation section")
    }

    private func situationCard(_ situation: ContextSituation) -> some View {
        AdaptiveGlassContainer {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
                if let freeform = situation.freeform, !freeform.isEmpty {
                    Text(freeform)
                        .font(.body)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                }

                // Show structured data if available
                if let occupation = situation.occupation {
                    structuredInfoRow(label: "Work", value: occupation)
                }

                if let lifeStage = situation.lifeStage {
                    structuredInfoRow(label: "Life Stage", value: lifeStage)
                }

                if let relationships = situation.relationships {
                    structuredInfoRow(label: "Relationships", value: relationships)
                }

                if let challenges = situation.challenges {
                    structuredInfoRow(label: "Challenges", value: challenges)
                }

                HStack {
                    Spacer()
                    Button {
                        viewModel.startEditingSituation()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(Color.terracotta)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit life situation")
                }
            }
        }
    }

    private func structuredInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xxs) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.warmGray400)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
    }

    // MARK: - Story 11.4: Discovery Section

    @ViewBuilder
    private func discoverySection(_ profile: ContextProfile) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            sectionHeader(
                title: "Your Discovery Session",
                icon: "sparkles",
                color: .terracotta
            )

            // Discovered on date
            if let discoveryDate = profile.discoveryCompletedAt {
                Text("Discovered on \(discoveryDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Color.warmGray400)
            }

            // Aha insight callout (Story 11.4 AC #6: editable)
            if let aha = profile.ahaInsight, !aha.isEmpty {
                AdaptiveGlassContainer {
                    VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                        HStack(spacing: DesignConstants.Spacing.xs) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.terracotta)
                            Text("Key Insight")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.terracotta)
                            Spacer()
                            discoveryEditButton(.ahaInsight)
                        }
                        Text(aha)
                            .font(.body)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .italic()
                    }
                }
                .accessibilityLabel("Key insight from your discovery session: \(aha)")
            }

            // Coaching domains as chips
            if !profile.coachingDomains.isEmpty {
                VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                    Text("Coaching Areas")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.warmGray400)

                    discoveryChipFlow(items: profile.coachingDomains)
                }
            }

            // Key themes
            if !profile.keyThemes.isEmpty {
                discoveryListField(label: "Key Themes", items: profile.keyThemes)
            }

            // Strengths
            if !profile.strengthsIdentified.isEmpty {
                discoveryListField(label: "Strengths", items: profile.strengthsIdentified)
            }

            // Vision (Story 11.4 AC #6: editable)
            if let vision = profile.vision, !vision.isEmpty {
                AdaptiveGlassContainer {
                    VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                        HStack {
                            Text("Your Vision")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.warmGray400)
                            Spacer()
                            discoveryEditButton(.vision)
                        }
                        Text(vision)
                            .font(.body)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }
            }

            // Communication style (Story 11.4 AC #6: editable)
            if let style = profile.communicationStyle, !style.isEmpty {
                editableDiscoveryRow(label: "Communication Style", value: style, key: .communicationStyle)
            }

            // Emotional baseline (Story 11.4 AC #6: editable)
            if let baseline = profile.emotionalBaseline, !baseline.isEmpty {
                editableDiscoveryRow(label: "Emotional Baseline", value: baseline, key: .emotionalBaseline)
            }

            // Current challenges
            if !profile.currentChallenges.isEmpty {
                discoveryListField(label: "Current Challenges", items: profile.currentChallenges)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Discovery session section. \(profile.coachingDomains.count) coaching areas identified.")
    }

    private func discoveryChipFlow(items: [String]) -> some View {
        FlowLayout(spacing: DesignConstants.Spacing.xs) {
            ForEach(items, id: \.self) { item in
                Text(item.capitalized)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, DesignConstants.Spacing.sm)
                    .padding(.vertical, DesignConstants.Spacing.xxs)
                    .background(Color.terracotta.opacity(0.12))
                    .foregroundStyle(Color.terracotta)
                    .clipShape(Capsule())
            }
        }
    }

    private func discoveryListField(label: String, items: [String]) -> some View {
        AdaptiveGlassContainer {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.warmGray400)

                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: DesignConstants.Spacing.xs) {
                        Circle()
                            .fill(Color.warmGray300)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }
            }
        }
    }

    // MARK: - Story 11.4 AC #6: Discovery Edit Helpers

    private func discoveryEditButton(_ key: DiscoveryFieldKey) -> some View {
        Button {
            viewModel.startEditingDiscoveryField(key)
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 14))
                .foregroundStyle(Color.warmGray400)
                .frame(width: DesignConstants.Size.minTouchTarget, height: DesignConstants.Size.minTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit")
    }

    private func editableDiscoveryRow(label: String, value: String, key: DiscoveryFieldKey) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xxs) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.warmGray400)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            Spacer()
            discoveryEditButton(key)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        ProfileSectionHeader(title: title, icon: icon, color: color)
    }

    private func emptySectionCard(message: String, icon: String) -> some View {
        AdaptiveGlassContainer {
            HStack(spacing: DesignConstants.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.warmGray300)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.warmGray500)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel(message)
    }

    private var loadingView: some View {
        VStack(spacing: DesignConstants.Spacing.md) {
            ProgressView()
                .tint(Color.terracotta)

            Text("Loading your profile...")
                .font(.subheadline)
                .foregroundStyle(Color.warmGray500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignConstants.Spacing.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading your profile")
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignConstants.Spacing.lg) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.warmGray300)

            Text("I'm still getting to know you")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("As we chat, I'll learn about your values, goals, and life situation. Everything I learn will show up here for you to review and edit.")
                .font(.subheadline)
                .foregroundStyle(Color.warmGray500)
                .multilineTextAlignment(.center)
        }
        .padding(DesignConstants.Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("I'm still getting to know you. As we chat, I'll learn about your values, goals, and life situation.")
    }

    // MARK: - Methods

    private func handleSave(item: ContextEditItem, newContent: String) async {
        switch item.type {
        case .value(let id):
            await viewModel.updateValue(id: id, newContent: newContent)
        case .goal(let id):
            await viewModel.updateGoal(id: id, newContent: newContent)
        case .situation:
            await viewModel.updateSituation(newContent: newContent)
        case .discoveryField(let key):
            await viewModel.updateDiscoveryField(key, newContent: newContent)
        }
    }
}

/// Reusable section header for profile sections (shared across Context views)
struct ProfileSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: DesignConstants.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct ContextProfileRowSurfaceModifier: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.standard, style: .continuous)
        if #available(iOS 26, *) {
            content
                .background {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                    shape
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.018 : 0.028))
                }
                .overlay(
                    shape
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.24), lineWidth: 1)
                )
                .clipShape(shape)
        } else {
            content
                .background(Color.adaptiveSurface(colorScheme))
                .clipShape(shape)
        }
    }
}

// MARK: - Previews

#Preview("With Profile") {
    ContextProfileView(userId: UUID())
}

#Preview("Loading") {
    ContextProfileView(userId: UUID())
}

#Preview("Dark Mode") {
    ContextProfileView(userId: UUID())
        .preferredColorScheme(.dark)
}
